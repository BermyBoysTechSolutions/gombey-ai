#!/usr/bin/env python3
"""Self-cleaning long-PDF retrieval smoke for an isolated Gombey RAG service.

Run inside the target RAG container with any subset of the approved synthetic
PDFs as positional arguments. The answer key is deliberately not accepted.
The script uses the container's configured embeddings credential, writes to a
unique temporary entity/file scope, and deletes only its own vectors.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


BASE_URL = os.environ.get("GOMBEY_RAG_SMOKE_URL", "http://127.0.0.1:8000").rstrip("/")
QUERY_DEPTH = int(os.environ.get("GOMBEY_RAG_SMOKE_QUERY_DEPTH", "20"))
ALLOWED_FILES = {
    "01-juniper-slate-studio-operations-manual.pdf",
    "02-juniper-slate-campaign-briefs.pdf",
    "03-juniper-slate-workflow-sops.pdf",
}
RUN_ID = uuid.uuid4().hex
ENTITY_ID = f"agent__gombey-long-corpus-{RUN_ID}"
WRONG_ENTITY_ID = f"agent__gombey-long-corpus-unrelated-{RUN_ID}"
FILES = {name: str(uuid.uuid4()) for name in sorted(ALLOWED_FILES)}

PROBES = [
    {
        "tag": "JS-C01",
        "file": "02-juniper-slate-campaign-briefs.pdf",
        "query": "What campaign title, launch date, and production budget are recorded for JS-C01?",
        "needles": ["winter blend preview", "2026-11-04", "2,400"],
    },
    {
        "file": "02-juniper-slate-campaign-briefs.pdf",
        "query": "What campaign title, launch date, review date, and target are recorded for JS-C12?",
        "needles": ["first friday open house", "2026-11-26", "817 product-page add-to-cart events"],
    },
    {
        "file": "02-juniper-slate-campaign-briefs.pdf",
        "query": "What is the campaign title, launch date, and target recorded for JS-C30?",
        "needles": ["focus friday pass", "2027-01-01", "1483 product-page add-to-cart events"],
    },
    {
        "file": "01-juniper-slate-studio-operations-manual.pdf",
        "query": "Who can authorize a public release, and can internal Gombey review replace that authorization?",
        "needles": [
            "only the named client approver can authorize public release",
            "internal review by gombey is not client approval",
        ],
    },
    {
        "file": "03-juniper-slate-workflow-sops.pdf",
        "query": "What steps are required when an approved source version is replaced?",
        "needles": [
            "replace the active document and retire the old version",
            "test a new fact and one retired fact after indexing",
        ],
    },
]


def request(method: str, path: str, *, body: bytes | None = None, headers=None):
    req = urllib.request.Request(
        f"{BASE_URL}{path}", data=body, headers=headers or {}, method=method
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            raw = response.read()
            try:
                parsed = json.loads(raw)
            except (json.JSONDecodeError, UnicodeDecodeError):
                parsed = raw.decode("utf-8", errors="replace")
            return response.status, parsed
    except urllib.error.HTTPError as error:
        # Provider error bodies can contain request context; never print them.
        return error.code, None


def normalized(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


def response_text(value, *, skip_keys=frozenset({"query", "entity_id", "file_id"})) -> str:
    parts: list[str] = []
    if isinstance(value, str):
        parts.append(value)
    elif isinstance(value, list):
        for item in value:
            parts.append(response_text(item, skip_keys=skip_keys))
    elif isinstance(value, dict):
        for key, item in value.items():
            if key not in skip_keys:
                parts.append(response_text(item, skip_keys=skip_keys))
    return " ".join(parts)


def collect_strings(value) -> set[str]:
    found: set[str] = set()
    if isinstance(value, str):
        found.add(value)
    elif isinstance(value, list):
        for item in value:
            found.update(collect_strings(item))
    elif isinstance(value, dict):
        for item in value.values():
            found.update(collect_strings(item))
    return found


def collect_document_hits(value) -> list[tuple[float | None, int | None, str]]:
    """Return passage score, page, and text for merged-window diagnostics."""
    hits: list[tuple[float | None, int | None, str]] = []
    if isinstance(value, list):
        # FastAPI serializes each LangChain (Document, distance) tuple as a
        # two-item JSON array. Keep the paired distance with its passage.
        if (
            len(value) == 2
            and isinstance(value[0], dict)
            and isinstance(value[0].get("page_content"), str)
            and isinstance(value[1], (float, int))
            and not isinstance(value[1], bool)
        ):
            document = value[0]
            metadata = document.get("metadata")
            page = None
            if isinstance(metadata, dict):
                page = next(
                    (
                        metadata[key]
                        for key in ("page", "page_number", "pageNumber")
                        if isinstance(metadata.get(key), int)
                        and not isinstance(metadata.get(key), bool)
                    ),
                    None,
                )
            hits.append(
                (float(value[1]), page, re.sub(r"\s+", " ", document["page_content"]))
            )
            return hits
        for item in value:
            hits.extend(collect_document_hits(item))
    elif isinstance(value, dict):
        content = value.get("page_content")
        if isinstance(content, str):
            metadata = value.get("metadata")
            page = None
            if isinstance(metadata, dict):
                page = next(
                    (
                        metadata[key]
                        for key in ("page", "page_number", "pageNumber")
                        if isinstance(metadata.get(key), int)
                        and not isinstance(metadata.get(key), bool)
                    ),
                    None,
                )
            score = next(
                (
                    value[key]
                    for key in ("distance", "score", "_distance")
                    if isinstance(value.get(key), (float, int))
                    and not isinstance(value.get(key), bool)
                ),
                None,
            )
            hits.append((float(score) if score is not None else None, page, re.sub(r"\s+", " ", content)))
        else:
            for item in value.values():
                hits.extend(collect_document_hits(item))
    return hits


def ids_for(entity_id: str):
    query = urllib.parse.urlencode({"entity_id": entity_id})
    return request("GET", f"/ids?{query}")


def embed(file_path: Path, file_id: str):
    boundary = f"----GombeyLongCorpus{RUN_ID}"
    content = file_path.read_bytes()
    parts = []
    for name, value in (("file_id", file_id), ("entity_id", ENTITY_ID)):
        parts.extend(
            [
                f"--{boundary}\r\n".encode(),
                f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode(),
                value.encode(),
                b"\r\n",
            ]
        )
    parts.extend(
        [
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="file"; filename="{file_path.name}"\r\n'.encode(),
            b"Content-Type: application/pdf\r\n\r\n",
            content,
            b"\r\n",
            f"--{boundary}--\r\n".encode(),
        ]
    )
    return request(
        "POST",
        "/embed",
        body=b"".join(parts),
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )


def query_file(file_id: str, entity_id: str, query: str):
    return request(
        "POST",
        "/query",
        body=json.dumps(
            {"query": query, "file_id": file_id, "entity_id": entity_id, "k": QUERY_DEPTH}
        ).encode(),
        headers={"Content-Type": "application/json"},
    )


def delete_files(file_ids: list[str]):
    query = urllib.parse.urlencode({"entity_id": ENTITY_ID})
    return request(
        "DELETE",
        f"/documents?{query}",
        body=json.dumps(file_ids).encode(),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
    )


def cleanup() -> bool:
    status, current = ids_for(ENTITY_ID)
    if status != 200:
        print(f"cleanup scope check HTTP {status}; absence is unverified", file=sys.stderr)
        return False

    present = sorted(set(FILES.values()) & collect_strings(current))
    if not present:
        print("cleanup check: no test vectors remain")
        return True

    status, _ = delete_files(present)
    print(f"cleanup DELETE HTTP {status} for {len(present)} test vectors")
    if status not in (200, 404):
        return False

    status, remaining = ids_for(ENTITY_ID)
    absent = status == 200 and not (set(FILES.values()) & collect_strings(remaining))
    print(f"post-cleanup ID check HTTP {status}; test_vectors_absent={absent}")
    return absent


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path)
    args = parser.parse_args()
    if not 1 <= QUERY_DEPTH <= 60:
        parser.error("GOMBEY_RAG_SMOKE_QUERY_DEPTH must be between 1 and 60")

    names = [path.name for path in args.files]
    if (
        not names
        or len(names) > len(ALLOWED_FILES)
        or len(set(names)) != len(names)
        or set(names) - ALLOWED_FILES
    ):
        parser.error("pass only unique numbered synthetic PDFs; never pass the answer key")
    if any(not path.is_file() or path.stat().st_size == 0 for path in args.files):
        parser.error("each approved PDF must exist and be non-empty")
    paths = {path.name: path for path in args.files}

    passed = True
    accepted = 0
    try:
        for name in sorted(paths):
            status, result = embed(paths[name], FILES[name])
            ok = status == 200 and isinstance(result, dict) and result.get("status")
            print(f"long PDF embed {name}: HTTP {status}; accepted={bool(ok)}")
            if not ok:
                passed = False
                break
            accepted += 1

        if accepted == len(paths):
            status, current = ids_for(ENTITY_ID)
            expected_ids = {FILES[name] for name in paths}
            visible = status == 200 and expected_ids.issubset(collect_strings(current))
            print(f"own-scope IDs HTTP {status}; all_selected_present={visible}")
            passed = passed and visible

        selected_probes = [probe for probe in PROBES if probe["file"] in paths]
        if passed and accepted == len(paths):
            for index, probe in enumerate(selected_probes, start=1):
                merged_hits = []
                statuses = []
                for name in sorted(paths):
                    status, result = query_file(FILES[name], ENTITY_ID, probe["query"])
                    statuses.append(status)
                    merged_hits.extend(collect_document_hits(result))
                ranked_hits = sorted(
                    merged_hits,
                    key=lambda hit: (hit[0] is None, hit[0] if hit[0] is not None else float("inf")),
                )
                context_hits = ranked_hits[:QUERY_DEPTH]
                raw_text = " ".join(hit[2] for hit in context_hits)
                text = normalized(raw_text)
                missing = [needle for needle in probe["needles"] if normalized(needle) not in text]
                fact_ranks = {
                    needle: next(
                        (
                            rank
                            for rank, (_score, _page, content) in enumerate(ranked_hits, start=1)
                            if normalized(needle) in normalized(content)
                        ),
                        None,
                    )
                    for needle in probe["needles"]
                }
                print(
                    f"long corpus merged retrieval {index}/{len(selected_probes)}: "
                    f"per_file_http={statuses}; context_limit={QUERY_DEPTH}; "
                    f"expected_facts_present={all(status == 200 for status in statuses) and not missing}"
                )
                print(f"  expected_fact_rank={fact_ranks}")
                if merged_hits and not any(hit[0] is not None for hit in merged_hits):
                    print("  merged-window score unavailable; ordering cannot be compared safely")
                    passed = False
                if missing:
                    pages = [hit[1] for hit in context_hits]
                    excerpt = raw_text[:600]
                    print(
                        f"  missing_expected={missing}; retrieved_pages={pages}; "
                        f"retrieved_excerpt={excerpt}"
                    )
                    for _score, page, snippet in context_hits:
                        print(f"  passage page={page}; text={snippet[:240]}")
                passed = passed and all(status == 200 for status in statuses) and not missing

                if probe.get("tag") == "JS-C30":
                    wrong_status, wrong = query_file(
                        FILES[probe["file"]], WRONG_ENTITY_ID,
                        "What campaign title is recorded for JS-C30?"
                    )
                    wrong_text = normalized(response_text(wrong))
                    leak = any(normalized(needle) in wrong_text for needle in probe["needles"])
                    print(
                        f"unrelated-scope query HTTP {wrong_status}; "
                        f"target_facts_leaked={leak}"
                    )
                    passed = passed and wrong_status == 200 and not leak

    except (OSError, TimeoutError, ValueError) as error:
        print(f"long corpus smoke failed: {type(error).__name__}", file=sys.stderr)
        passed = False
    finally:
        try:
            passed = cleanup() and passed
        except (OSError, TimeoutError, ValueError) as error:
            print(f"long corpus cleanup unverified: {type(error).__name__}", file=sys.stderr)
            passed = False

    return 0 if passed and accepted == len(paths) else 1


if __name__ == "__main__":
    sys.exit(main())
