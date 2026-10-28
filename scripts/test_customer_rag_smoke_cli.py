from __future__ import annotations

import os
import subprocess
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
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

    def test_failed_ingest_does_not_delete_when_scoped_check_is_empty(self) -> None:
        class Handler(BaseHTTPRequestHandler):
            delete_calls = 0

            def log_message(self, *_args) -> None:
                pass

            def _reply(self, status: int, payload: bytes) -> None:
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

            def do_POST(self) -> None:
                self._reply(500, b'{"status":false}')

            def do_GET(self) -> None:
                self._reply(200, b'{"ids":[]}')

            def do_DELETE(self) -> None:
                type(self).delete_calls += 1
                self._reply(200, b'{"status":true}')

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        env = os.environ.copy()
        env["GOMBEY_RAG_SMOKE_URL"] = f"http://127.0.0.1:{server.server_port}"
        try:
            result = subprocess.run(
                [sys.executable, str(SCRIPT)],
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
                env=env,
            )
        finally:
            server.shutdown()
            server.server_close()
            worker.join(timeout=2)

        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("synthetic embed HTTP 500", result.stdout)
        self.assertIn("vector_absent=True", result.stdout)
        self.assertEqual(Handler.delete_calls, 0)


if __name__ == "__main__":
    unittest.main()
