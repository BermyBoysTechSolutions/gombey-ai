#!/usr/bin/env python3
"""Offline tests for the customer USER-role setup helper."""

import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from apply_member_role import ROLE_PROFILE, SetupError, configure_member_role, validate_base_url


class RoleApiHandler(BaseHTTPRequestHandler):
    requests = []
    two_factor = False

    def log_message(self, format, *args):
        return

    def _body(self):
        length = int(self.headers.get("Content-Length", "0"))
        return json.loads(self.rfile.read(length))

    def _json(self, payload, status=200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        payload = self._body()
        self.requests.append((self.command, self.path, dict(self.headers), payload))
        if self.path == "/api/auth/login":
            if self.two_factor:
                self._json({"twoFAPending": True, "tempToken": "synthetic-temp-token"})
            else:
                self._json({"token": "synthetic-admin-token"})
        elif self.path == "/api/auth/2fa/verify-temp":
            self._json({"token": "synthetic-admin-token"})
        else:
            self._json({"error": "unexpected"}, 404)

    def do_PATCH(self):
        payload = self._body()
        self.requests.append((self.command, self.path, dict(self.headers), payload))
        self._json({"role": {"name": "USER", "permissions": payload.get("permissions")}})


class ApplyMemberRoleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), RoleApiHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base_url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def setUp(self):
        RoleApiHandler.requests = []
        RoleApiHandler.two_factor = False

    def test_rejects_non_loopback_plain_http(self):
        with self.assertRaises(SetupError):
            validate_base_url("http://chat.example.test")

    def test_rejects_url_credentials_or_path(self):
        for url in (
            "https://admin:secret@chat.example.test",
            "https://chat.example.test/customer",
            "https://chat.example.test/?token=secret",
        ):
            with self.subTest(url=url), self.assertRaises(SetupError):
                validate_base_url(url)

    def test_applies_exact_profile_and_verifies_response(self):
        configure_member_role(self.base_url, "admin@example.test", "hidden-password", lambda: "")
        self.assertEqual(len(RoleApiHandler.requests), 2)
        login_method, login_path, login_headers, login_body = RoleApiHandler.requests[0]
        self.assertEqual((login_method, login_path), ("POST", "/api/auth/login"))
        self.assertEqual(login_body, {"email": "admin@example.test", "password": "hidden-password"})
        self.assertEqual(login_headers.get("Origin"), self.base_url)
        method, path, headers, body = RoleApiHandler.requests[1]
        self.assertEqual((method, path), ("PATCH", "/api/admin/roles/USER/permissions"))
        self.assertEqual(headers.get("Authorization"), "Bearer synthetic-admin-token")
        self.assertEqual(body, {"permissions": ROLE_PROFILE})

    def test_handles_two_factor_challenge(self):
        RoleApiHandler.two_factor = True
        configure_member_role(self.base_url, "admin@example.test", "hidden-password", lambda: "123456")
        self.assertEqual(
            [request[1] for request in RoleApiHandler.requests],
            ["/api/auth/login", "/api/auth/2fa/verify-temp", "/api/admin/roles/USER/permissions"],
        )
        self.assertEqual(RoleApiHandler.requests[1][3], {"tempToken": "synthetic-temp-token", "token": "123456"})

    def test_non_admin_login_does_not_attempt_role_update(self):
        class ForbiddenHandler(RoleApiHandler):
            def do_POST(self):
                self._body()
                self._json({"message": "sensitive server detail"}, 401)

        server = ThreadingHTTPServer(("127.0.0.1", 0), ForbiddenHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with self.assertRaisesRegex(SetupError, "HTTP 401") as raised:
                configure_member_role(
                    f"http://127.0.0.1:{server.server_port}",
                    "member@example.test",
                    "hidden-password",
                    lambda: "",
                )
            self.assertNotIn("sensitive server detail", str(raised.exception))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_rejects_a_success_response_with_the_wrong_saved_profile(self):
        class MismatchHandler(RoleApiHandler):
            def do_PATCH(self):
                self._body()
                self._json({"role": {"name": "USER", "permissions": {"AGENTS": {"USE": True, "CREATE": True}}}})

        server = ThreadingHTTPServer(("127.0.0.1", 0), MismatchHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with self.assertRaisesRegex(SetupError, "did not match"):
                configure_member_role(
                    f"http://127.0.0.1:{server.server_port}",
                    "admin@example.test",
                    "hidden-password",
                    lambda: "",
                )
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
