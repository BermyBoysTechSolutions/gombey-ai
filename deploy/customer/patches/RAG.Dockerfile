ARG UPSTREAM_RAG_IMAGE
FROM --platform=linux/amd64 ${UPSTREAM_RAG_IMAGE}

COPY rag-fail-closed.py /app/gombey-rag-fail-closed.py

CMD ["sh", "-lc", "python /app/gombey-rag-fail-closed.py && exec python main.py"]
