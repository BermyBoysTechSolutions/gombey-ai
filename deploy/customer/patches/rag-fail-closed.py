#!/usr/bin/env python3
"""Fail closed when the pinned LibreChat RAG API catches embedding errors."""

from __future__ import annotations

import os
import stat
import tempfile
from pathlib import Path


SOURCE = Path("/app/app/routes/document_routes.py")
ORIGINAL = '        return {"message": "An error occurred while adding documents.", "error": str(e)}'
PATCHED = (
    "        return None  # Gombey MVP: callers must fail failed embeddings."
)


def patch_source(source: Path = SOURCE) -> bool:
    """Replace the exact upstream error return; refuse unknown source shapes."""
    content = source.read_text(encoding="utf-8")
    original_count = content.count(ORIGINAL)
    patched_count = content.count(PATCHED)

    if original_count == 0 and patched_count == 1:
        return False
    if original_count != 1 or patched_count != 0:
        raise RuntimeError(
            "Unexpected LibreChat RAG source shape; refusing an unverified patch."
        )

    updated = content.replace(ORIGINAL, PATCHED, 1)
    source_stat = source.stat()
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{source.name}.", suffix=".gombey.tmp", dir=source.parent
    )
    try:
        os.fchmod(descriptor, stat.S_IMODE(source_stat.st_mode))
        with os.fdopen(descriptor, "w", encoding="utf-8") as temporary:
            descriptor = -1
            temporary.write(updated)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_name, source)
    except Exception:
        if descriptor >= 0:
            os.close(descriptor)
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise
    return True


if __name__ == "__main__":
    changed = patch_source()
    print("RAG failure handling patched." if changed else "RAG failure handling already patched.")
