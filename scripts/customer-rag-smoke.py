#!/usr/bin/env python3
"""Exercise a customer RAG API with one synthetic, self-cleaning document.

Run inside the target RAG container:
  docker exec -i <rag-container> python - < scripts/customer-rag-smoke.py

No API key is accepted on the command line or printed. The script uses the
container's configured embeddings credential, creates a unique entity/file
scope, checks retrieval and scope isolation, and removes its vector in a
finally block.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid


BASE_URL = os.environ.get("GOMBEY_RAG_SMOKE_URL", "http://127.0.0.1:8000").rstrip("/")
RUN_ID = uuid.uuid4().hex
FILE_ID = f"gombey-rag-smoke-{RUN_ID}"
ENTITY_ID = f"agent__gombey-rag-smoke-{RUN_ID}"
WRONG_ENTITY_ID = f"agent__gombey-rag-smoke-unrelated-{RUN_ID}"
MARKER = f"GOMBEY-SYNTHETIC-MARKER-{RUN_ID}"
TEXT = (
    "Synthetic Gombey RAG acceptance fixture. This contains no customer data. "
    f"The exact fictional launch marker is {MARKER}."
).encode()


def request(method: str, path: str, *, body: bytes | None = None, headers=None):
    req = urllib.request.Request(
        f"{BASE_URL}{path}", data=body, headers=headers or {}, method=method
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            raw = response.read()
            try:
                parsed = json.loads(raw)
            except (json.JSONDecodeError, UnicodeDecodeError):
                parsed = raw.decode("utf-8", errors="replace")
            return response.status, parsed
    except urllib.error.HTTPError as error:
        # Keep provider error bodies out of logs; they may contain request data.
        return error.code, None


def collect_ids(value) -> set[str]:
    found: set[str] = set()
    if isinstance(value, str):
        found.add(value)
    elif isinstance(value, list):
        for item in value:
            found.update(collect_ids(item))
    elif isinstance(value, dict):
        for key, item in value.items():
            if key in {"id", "ids", "file_id", "document_id"}:
                found.update(collect_ids(item))
            elif isinstance(item, (dict, list)):
                found.update(collect_ids(item))
    return found


def contains_marker(value) -> bool:
    if isinstance(value, str):
        return MARKER in value
    if isinstance(value, list):
        return any(contains_marker(item) for item in value)
    if isinstance(value, dict):
        return any(contains_marker(item) for item in value.values())
    return False


def embed():
    boundary = f"----GombeyRagSmoke{RUN_ID}"
    chunks = []
    for name, value in (("file_id", FILE_ID), ("entity_id", ENTITY_ID)):
        chunks.extend(
            [
                f"--{boundary}\r\n".encode(),
                f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode(),
                value.encode(),
                b"\r\n",
            ]
        )
    chunks.extend(
        [
            f"--{boundary}\r\n".encode(),
            (
                'Content-Disposition: form-data; name="file"; '
                'filename="gombey-synthetic-rag-smoke.txt"\r\n'
            ).encode(),
            b"Content-Type: text/plain\r\n\r\n",
            TEXT,
            b"\r\n",
            f"--{boundary}--\r\n".encode(),
        ]
    )
    return request(
        "POST",
        "/embed",
        body=b"".join(chunks),
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )


def ids_for(entity_id: str):
    query = urllib.parse.urlencode({"entity_id": entity_id})
    return request("GET", f"/ids?{query}")


def delete_fixture():
    query = urllib.parse.urlencode({"entity_id": ENTITY_ID})
    return request(
        "DELETE",
        f"/documents?{query}",
        body=json.dumps([FILE_ID]).encode(),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
    )


def main() -> int:
    passed = False
    try:
        status, result = embed()
        print(f"synthetic embed HTTP {status}")
        if status != 200 or not isinstance(result, dict) or not result.get("status"):
            return_code = 1
        else:
            return_code = 0

        if return_code == 0:
            status, own_ids = ids_for(ENTITY_ID)
            print(f"own-scope ID check HTTP {status}")
            if status != 200 or FILE_ID not in collect_ids(own_ids):
                return_code = 1

        if return_code == 0:
            status, other_ids = ids_for(WRONG_ENTITY_ID)
            print(f"unrelated-scope ID check HTTP {status}")
            if status != 200 or FILE_ID in collect_ids(other_ids):
                return_code = 1

        if return_code == 0:
            status, result = request(
                "POST",
                "/query",
                body=json.dumps(
                    {
                        "query": "What is the exact fictional launch marker?",
                        "file_id": FILE_ID,
                        "entity_id": ENTITY_ID,
                        "k": 4,
                    }
                ).encode(),
                headers={"Content-Type": "application/json"},
            )
            marker_found = contains_marker(result)
            print(f"synthetic retrieval HTTP {status}; marker_found={marker_found}")
            if status != 200 or not marker_found:
                return_code = 1
        passed = return_code == 0
    except (OSError, TimeoutError, ValueError) as error:
        print(f"RAG smoke failed: {type(error).__name__}", file=sys.stderr)
        passed = False
    finally:
        status, _ = delete_fixture()
        print(f"synthetic vector cleanup HTTP {status}")
        if status not in (200, 404):
            print("cleanup requires follow-up; do not use this RAG service for real data", file=sys.stderr)
            passed = False
        status, remaining = ids_for(ENTITY_ID)
        remaining_ids = collect_ids(remaining)
        absent = status == 200 and FILE_ID not in remaining_ids
        print(f"post-cleanup ID check HTTP {status}; vector_absent={absent}")
        passed = passed and absent

    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
