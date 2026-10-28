from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("customer-rag-smoke.py")


class CustomerRagSmokeCliTests(unittest.TestCase):
    def test_help_is_inert(self) -> None:
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--help"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("usage:", result.stdout.lower())
        self.assertNotIn("synthetic embed HTTP", result.stdout)

    def test_unavailable_service_reports_cleanup_uncertainty_without_traceback(self) -> None:
        env = os.environ.copy()
        env["GOMBEY_RAG_SMOKE_URL"] = "http://127.0.0.1:1"
        result = subprocess.run(
            [sys.executable, str(SCRIPT)],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
            env=env,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RAG smoke failed:", result.stderr)
        self.assertIn("cleanup could not be confirmed:", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
