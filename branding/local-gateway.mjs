import http from 'node:http';
import { URL } from 'node:url';
import { getDocument } from 'pdfjs-dist/legacy/build/pdf.mjs';

const listenPort = Number(process.env.LISTEN_PORT || 11434);
const upstreamBaseUrl = new URL(process.env.OLLAMA_UPSTREAM_URL || 'http://host.docker.internal:11434');
const maxRequestBytes = Number(process.env.MAX_REQUEST_BYTES || 160 * 1024 * 1024);
const maxExtractedChars = Number(process.env.MAX_EXTRACTED_CHARS || 250_000);
const minimumOutputTokens = Number(process.env.MIN_OUTPUT_TOKENS || 8192);
const contextTokens = Number(process.env.OLLAMA_CONTEXT_TOKENS || 16384);

if (upstreamBaseUrl.pathname === '/v1') {
  upstreamBaseUrl.pathname = '';
}

const hopByHopHeaders = new Set([
  'connection',
  'content-length',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
]);

function writeJson(response, status, body) {
  const payload = JSON.stringify(body);
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(payload),
  });
  response.end(payload);
}

function summarizePayload(payload) {
  const messages = Array.isArray(payload?.messages) ? payload.messages : [];
  let fileCount = 0;
  let textChars = 0;
  const contentTypes = new Set();

  for (const message of messages) {
    if (typeof message?.content === 'string') {
      textChars += message.content.length;
      contentTypes.add('string');
      continue;
    }

    if (!Array.isArray(message?.content)) {
      continue;
    }

    for (const part of message.content) {
      contentTypes.add(part?.type || 'unknown');
      if (part?.type === 'file') {
        fileCount += 1;
      }
      if (part?.type === 'text' && typeof part.text === 'string') {
        textChars += part.text.length;
      }
    }
  }

  return {
    model: payload?.model || null,
    stream: payload?.stream === true,
    maxTokens: payload?.max_tokens ?? payload?.max_completion_tokens ?? null,
    messageCount: messages.length,
    fileCount,
    textChars,
    contentTypes: [...contentTypes],
  };
}

function updateStreamStats(stats, line) {
  if (!line.startsWith('data: ') || line === 'data: [DONE]') {
    return;
  }

  try {
    const event = JSON.parse(line.slice(6));
    const choice = event.choices?.[0];
    const delta = choice?.delta || {};
    if (typeof delta.content === 'string') {
      stats.contentChars += delta.content.length;
    }
    if (typeof delta.reasoning === 'string') {
      stats.reasoningChars += delta.reasoning.length;
    }
    if (choice?.finish_reason) {
      stats.finishReason = choice.finish_reason;
    }
  } catch {
    // Preserve the upstream stream even if a provider sends a non-JSON event.
  }
}

async function readRequestBody(request) {
  const chunks = [];
  let size = 0;

  for await (const chunk of request) {
    size += chunk.length;
    if (size > maxRequestBytes) {
      const error = new Error(`request exceeds the ${maxRequestBytes} byte limit`);
      error.statusCode = 413;
      throw error;
    }
    chunks.push(chunk);
  }

  return Buffer.concat(chunks).toString('utf8');
}

function decodeDataUrl(value, filename) {
  if (typeof value !== 'string') {
    throw new Error(`attached file ${filename} did not include file data`);
  }

  if (!value.startsWith('data:')) {
    throw new Error(`attached file ${filename} is not embedded in the request`);
  }

  const commaIndex = value.indexOf(',');
  if (commaIndex < 0) {
    throw new Error(`attached file ${filename} has an invalid data URL`);
  }

  const metadata = value.slice(5, commaIndex);
  const encoded = value.slice(commaIndex + 1);
  if (!metadata.split(';').includes('base64')) {
    throw new Error(`attached file ${filename} is not base64 encoded`);
  }

  return Buffer.from(encoded, 'base64');
}

async function extractPdfText(bytes) {
  const loadingTask = getDocument({
    data: new Uint8Array(bytes),
    disableWorker: true,
    useWorkerFetch: false,
    isEvalSupported: false,
    verbosity: 0,
  });
  const document = await loadingTask.promise;
  const pages = [];

  try {
    for (let pageNumber = 1; pageNumber <= document.numPages; pageNumber += 1) {
      const page = await document.getPage(pageNumber);
      const content = await page.getTextContent();
      const pageText = content.items
        .map((item) => ('str' in item ? item.str : ''))
        .filter(Boolean)
        .join(' ')
        .trim();

      if (pageText) {
        pages.push(`Page ${pageNumber}\n${pageText}`);
      }
    }
  } finally {
    await document.destroy();
  }

  return pages.join('\n\n').slice(0, maxExtractedChars).trim();
}

async function normalizeContent(content, stats) {
  if (!Array.isArray(content)) {
    return content;
  }

  const normalized = [];
  for (const part of content) {
    if (!part || part.type !== 'file') {
      normalized.push(part);
      continue;
    }

    const file = part.file || {};
    const filename = file.filename || 'attached-document.pdf';
    const fileData = file.file_data || file.data;
    const bytes = decodeDataUrl(fileData, filename);
    const text = await extractPdfText(bytes);

    if (!text) {
      throw new Error(`attached PDF ${filename} contains no extractable text`);
    }

    stats.pdfCount += 1;
    stats.extractedChars += text.length;
    normalized.push({
      type: 'text',
      text: `\n\n[Attached document: ${filename}]\n${text}\n[End attached document]`,
    });
  }

  return normalized;
}

async function normalizePayload(payload) {
  if (!payload || !Array.isArray(payload.messages)) {
    return { payload, stats: { pdfCount: 0, extractedChars: 0 } };
  }

  const stats = { pdfCount: 0, extractedChars: 0 };
  const messages = [];
  for (const message of payload.messages) {
    messages.push({
      ...message,
      content: await normalizeContent(message.content, stats),
    });
  }

  const normalizedPayload = { ...payload, messages };
  const requestedOutputTokens = Number(
    normalizedPayload.max_tokens ?? normalizedPayload.max_completion_tokens,
  );
  if (!Number.isFinite(requestedOutputTokens) || requestedOutputTokens < minimumOutputTokens) {
    normalizedPayload.max_tokens = minimumOutputTokens;
    delete normalizedPayload.max_completion_tokens;
  }

  return { payload: normalizedPayload, stats };
}

function upstreamUrlFor(pathname, search) {
  const url = new URL(upstreamBaseUrl);
  url.pathname = `${url.pathname.replace(/\/$/, '')}${pathname}`;
  url.search = search;
  return url;
}

function decodeImageDataUrl(value) {
  if (typeof value !== 'string' || !value.startsWith('data:image/')) {
    throw new Error('local image attachments must be embedded data URLs');
  }

  const commaIndex = value.indexOf(',');
  if (commaIndex < 0 || !value.slice(0, commaIndex).split(';').includes('base64')) {
    throw new Error('local image attachment has an invalid data URL');
  }

  return value.slice(commaIndex + 1);
}

function toOllamaMessage(message) {
  const role = message.role === 'developer' ? 'system' : message.role || 'user';
  const images = [];
  let content = '';

  if (typeof message.content === 'string') {
    content = message.content;
  } else if (Array.isArray(message.content)) {
    const textParts = [];
    for (const part of message.content) {
      if (part?.type === 'text' && typeof part.text === 'string') {
        textParts.push(part.text);
      } else if (part?.type === 'image_url') {
        images.push(decodeImageDataUrl(part.image_url?.url));
      } else if (part?.type === 'file') {
        throw new Error('local file attachments must be converted before model execution');
      }
    }
    content = textParts.join('\n');
  }

  const converted = { role, content };
  if (images.length > 0) {
    converted.images = images;
  }
  if (message.name) {
    converted.name = message.name;
  }
  if (Array.isArray(message.tool_calls)) {
    converted.tool_calls = message.tool_calls;
  }
  return converted;
}

function nativeOptionsFor(payload) {
  const options = {
    ...(payload.options && typeof payload.options === 'object' ? payload.options : {}),
    num_ctx: Math.max(Number(payload.options?.num_ctx) || 0, contextTokens),
  };
  const requestedOutputTokens = Number(
    payload.max_tokens ?? payload.max_completion_tokens,
  );
  options.num_predict = Number.isFinite(requestedOutputTokens) && requestedOutputTokens > 0
    ? requestedOutputTokens
    : minimumOutputTokens;

  for (const key of ['temperature', 'top_p', 'top_k', 'seed', 'repeat_penalty', 'stop']) {
    if (payload[key] !== undefined) {
      options[key] = payload[key];
    }
  }
  return options;
}

function nativeUsage(nativeResponse) {
  const promptTokens = nativeResponse.prompt_eval_count || 0;
  const completionTokens = nativeResponse.eval_count || 0;
  return {
    prompt_tokens: promptTokens,
    completion_tokens: completionTokens,
    total_tokens: promptTokens + completionTokens,
  };
}

function openAIResponseFromNative(nativeResponse, payload) {
  const content = nativeResponse.message?.content || '';
  return {
    id: `chatcmpl-${Date.now().toString(36)}`,
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model: nativeResponse.model || payload.model,
    choices: [{
      index: 0,
      message: { role: 'assistant', content },
      finish_reason: nativeResponse.done_reason === 'length' ? 'length' : 'stop',
    }],
    usage: nativeUsage(nativeResponse),
  };
}

function writeOpenAIChunk(response, { id, model, created, delta, finishReason = null, usage }) {
  const chunk = {
    id,
    object: 'chat.completion.chunk',
    created,
    model,
    choices: [{ index: 0, delta, finish_reason: finishReason }],
  };
  if (usage) {
    chunk.usage = usage;
  }
  response.write(`data: ${JSON.stringify(chunk)}\n\n`);
}

async function proxyNativeChat(response, payload, headers) {
  const nativePayload = {
    model: payload.model,
    messages: payload.messages.map(toOllamaMessage),
    stream: payload.stream === true,
    think: false,
    options: nativeOptionsFor(payload),
  };
  if (payload.keep_alive !== undefined) {
    nativePayload.keep_alive = payload.keep_alive;
  }

  const nativeResponse = await fetch(upstreamUrlFor('/api/chat', ''), {
    method: 'POST',
    headers,
    body: JSON.stringify(nativePayload),
    signal: AbortSignal.timeout(15 * 60 * 1000),
  });

  if (!nativeResponse.ok) {
    const errorBody = await nativeResponse.text();
    response.writeHead(nativeResponse.status, {
      'content-type': nativeResponse.headers.get('content-type') || 'application/json; charset=utf-8',
    });
    response.end(errorBody);
    return;
  }

  if (payload.stream !== true) {
    const nativeBody = await nativeResponse.json();
    const openAIResponse = openAIResponseFromNative(nativeBody, payload);
    writeJson(response, 200, openAIResponse);
    return;
  }

  const id = `chatcmpl-${Date.now().toString(36)}`;
  const created = Math.floor(Date.now() / 1000);
  const model = payload.model;
  response.writeHead(200, {
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-cache',
    connection: 'keep-alive',
    'x-accel-buffering': 'no',
  });

  let buffer = '';
  let roleSent = false;
  let finalResponse;
  const decoder = new TextDecoder();
  const processLine = (line) => {
    if (!line.trim()) {
      return;
    }
    const nativeChunk = JSON.parse(line);
    const chunkContent = nativeChunk.message?.content || '';
    if (!roleSent) {
      writeOpenAIChunk(response, { id, model, created, delta: { role: 'assistant', content: '' } });
      roleSent = true;
    }
    if (chunkContent) {
      writeOpenAIChunk(response, { id, model, created, delta: { content: chunkContent } });
    }
    if (nativeChunk.done) {
      finalResponse = nativeChunk;
    }
  };

  for await (const chunk of nativeResponse.body || []) {
    buffer += decoder.decode(chunk, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';
    for (const line of lines) {
      processLine(line);
    }
  }
  buffer += decoder.decode();
  if (buffer.trim()) {
    processLine(buffer);
  }
  if (!roleSent) {
    writeOpenAIChunk(response, { id, model, created, delta: { role: 'assistant', content: '' } });
  }

  writeOpenAIChunk(response, {
    id,
    model,
    created,
    delta: {},
    finishReason: finalResponse?.done_reason === 'length' ? 'length' : 'stop',
    usage: finalResponse ? nativeUsage(finalResponse) : undefined,
  });
  response.write('data: [DONE]\n\n');
  response.end();
}

async function proxyRequest(request, response) {
  const requestUrl = new URL(request.url || '/', 'http://local-gateway');
  const targetUrl = upstreamUrlFor(requestUrl.pathname, requestUrl.search);
  const headers = new Headers(request.headers);
  headers.delete('host');
  headers.delete('content-length');

  let body;
  let stats = { pdfCount: 0, extractedChars: 0 };
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    body = await readRequestBody(request);
    if ((headers.get('content-type') || '').includes('application/json') && body) {
      const parsed = JSON.parse(body);
      const normalized = await normalizePayload(parsed);
      body = JSON.stringify(normalized.payload);
      stats = normalized.stats;
      headers.set('content-type', 'application/json');
      console.log(`[local-gateway] request ${JSON.stringify({ ...summarizePayload(normalized.payload), extractedPdfCount: stats.pdfCount, extractedChars: stats.extractedChars })}`);

      if (
        request.method === 'POST' &&
        requestUrl.pathname === '/v1/chat/completions' &&
        Array.isArray(normalized.payload.messages)
      ) {
        await proxyNativeChat(response, normalized.payload, headers);
        if (stats.pdfCount > 0) {
          console.log(`[local-gateway] extracted ${stats.pdfCount} PDF attachment(s), ${stats.extractedChars} text characters`);
        }
        return;
      }
    }
  }

  const upstreamResponse = await fetch(targetUrl, {
    method: request.method,
    headers,
    body,
    signal: AbortSignal.timeout(15 * 60 * 1000),
  });

  const responseHeaders = {};
  for (const [name, value] of upstreamResponse.headers) {
    if (!hopByHopHeaders.has(name.toLowerCase())) {
      responseHeaders[name] = value;
    }
  }
  response.writeHead(upstreamResponse.status, responseHeaders);

  const streamStats = {
    contentChars: 0,
    reasoningChars: 0,
    finishReason: null,
  };
  const isEventStream = (upstreamResponse.headers.get('content-type') || '').includes('text/event-stream');
  let eventBuffer = '';

  if (upstreamResponse.body) {
    for await (const chunk of upstreamResponse.body) {
      response.write(chunk);
      if (isEventStream) {
        eventBuffer += new TextDecoder().decode(chunk);
        const lines = eventBuffer.split('\n');
        eventBuffer = lines.pop() || '';
        for (const line of lines) {
          updateStreamStats(streamStats, line.trimEnd());
        }
      }
    }
  }
  response.end();

  if (isEventStream) {
    console.log(`[local-gateway] stream ${JSON.stringify(streamStats)}`);
  }

  if (stats.pdfCount > 0) {
    console.log(`[local-gateway] extracted ${stats.pdfCount} PDF attachment(s), ${stats.extractedChars} text characters`);
  }
}

const server = http.createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/health') {
    writeJson(response, 200, { status: 'ok', mode: 'local-pdf-and-context-adapter' });
    return;
  }

  try {
    await proxyRequest(request, response);
  } catch (error) {
    const statusCode = error.statusCode || 502;
    console.error(`[local-gateway] ${statusCode}: ${error.message}`);
    if (!response.headersSent) {
      writeJson(response, statusCode, {
        error: {
          message: error.message,
          type: statusCode === 413 ? 'request_too_large' : 'local_document_processing_error',
        },
      });
    } else {
      response.destroy(error);
    }
  }
});

server.listen(listenPort, '0.0.0.0', () => {
  console.log(`[local-gateway] listening on ${listenPort}; local upstream ${upstreamBaseUrl.origin}`);
});
