"""Unit tests for the secure RAG-key writer; all keys here are fake."""

import importlib.util
import io
import os
import stat
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("set_rag_embeddings_key.py")
SPEC = importlib.util.spec_from_file_location("set_rag_embeddings_key", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SetRagEmbeddingsKeyTests(unittest.TestCase):
    def make_env(
        self,
        directory: str,
        content: str = "A=1\nRAG_OPENAI_API_KEY=placeholder\nZ=3\n",
    ) -> Path:
        env_path = Path(directory) / ".env"
        env_path.write_text(content, encoding="utf-8")
        env_path.chmod(0o600)
        return env_path

    def test_replaces_only_key_and_preserves_mode(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            env_path = self.make_env(directory)
            MODULE.update_env_key(env_path, "FAKE_TEST_KEY_NOT_REAL")
            self.assertEqual(
                env_path.read_text(encoding="utf-8"),
                "A=1\nRAG_OPENAI_API_KEY=FAKE_TEST_KEY_NOT_REAL\nZ=3\n",
            )
            self.assertEqual(stat.S_IMODE(env_path.stat().st_mode), 0o600)

    def test_disable_replaces_key_with_placeholder_without_touching_other_settings(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            env_path = self.make_env(
                directory,
                "A=1\nRAG_OPENAI_API_KEY=FAKE_TEST_KEY_NOT_REAL\nZ=3\n",
            )
            MODULE.disable_env_key(env_path)
            self.assertEqual(
                env_path.read_text(encoding="utf-8"),
                "A=1\nRAG_OPENAI_API_KEY=REPLACE_WITH_CUSTOMER_OWNED_EMBEDDINGS_API_KEY\nZ=3\n",
            )
            self.assertEqual(stat.S_IMODE(env_path.stat().st_mode), 0o600)

    def test_rejects_duplicate_entries_without_modifying_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            env_path = self.make_env(
                directory, "RAG_OPENAI_API_KEY=one\nRAG_OPENAI_API_KEY=two\n"
            )
            before = env_path.read_bytes()
            with self.assertRaisesRegex(ValueError, "exactly one"):
                MODULE.update_env_key(env_path, "fake-key")
            self.assertEqual(env_path.read_bytes(), before)

    def test_rejects_placeholders_and_multiline_values(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            env_path = self.make_env(directory)
            for invalid in ("user_provided", "REPLACE_ME", "fake\nSECOND=value"):
                with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                    MODULE.update_env_key(env_path, invalid)

    def test_rejects_unsafe_file_permissions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            env_path = self.make_env(directory)
            env_path.chmod(0o640)
            with self.assertRaisesRegex(ValueError, "mode 600"):
                MODULE.update_env_key(env_path, "fake-key")

    def test_rejects_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = self.make_env(directory)
            link = Path(directory) / ".env-link"
            link.symlink_to(target)
            with self.assertRaisesRegex(ValueError, "not a symlink"):
                MODULE.update_env_key(link, "fake-key")

    def test_directory_fsync_warning_does_not_misreport_atomic_update(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            env_path = self.make_env(directory)
            warning = io.StringIO()
            with redirect_stderr(warning), patch.object(
                MODULE.os, "fsync", side_effect=[None, OSError("test only")]
            ):
                MODULE.update_env_key(env_path, "FAKE_TEST_KEY_NOT_REAL")
            self.assertIn("key file was updated", warning.getvalue())
            self.assertIn(
                "RAG_OPENAI_API_KEY=FAKE_TEST_KEY_NOT_REAL",
                env_path.read_text(encoding="utf-8"),
            )


if __name__ == "__main__":
    unittest.main()
