#!/usr/bin/env python3
"""Tests for the pinned RAG API fail-closed compatibility patch."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

PATCH_PATH = Path(__file__).resolve().parents[1] / "deploy/customer/patches/rag-fail-closed.py"
SPEC = importlib.util.spec_from_file_location("rag_fail_closed", PATCH_PATH)
assert SPEC is not None and SPEC.loader is not None
PATCH_MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATCH_MODULE)
ORIGINAL = PATCH_MODULE.ORIGINAL
PATCHED = PATCH_MODULE.PATCHED
patch_source = PATCH_MODULE.patch_source


class RagFailClosedPatchTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.source = Path(self.temp_dir.name) / "document_routes.py"

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_replaces_upstream_truthy_error_return(self) -> None:
        self.source.write_text(f"before\n{ORIGINAL}\nafter\n", encoding="utf-8")
        self.assertTrue(patch_source(self.source))
        self.assertEqual(self.source.read_text(encoding="utf-8"), f"before\n{PATCHED}\nafter\n")

    def test_is_idempotent(self) -> None:
        self.source.write_text(f"{PATCHED}\n", encoding="utf-8")
        self.assertFalse(patch_source(self.source))

    def test_refuses_unrecognized_source_without_modifying_it(self) -> None:
        content = "upstream changed\n"
        self.source.write_text(content, encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "Unexpected LibreChat RAG source shape"):
            patch_source(self.source)
        self.assertEqual(self.source.read_text(encoding="utf-8"), content)

    def test_refuses_multiple_upstream_matches(self) -> None:
        content = f"{ORIGINAL}\n{ORIGINAL}\n"
        self.source.write_text(content, encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "Unexpected LibreChat RAG source shape"):
            patch_source(self.source)
        self.assertEqual(self.source.read_text(encoding="utf-8"), content)


if __name__ == "__main__":
    unittest.main(verbosity=2)
