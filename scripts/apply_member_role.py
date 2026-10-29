#!/usr/bin/env python3
"""Apply and verify Gombey's least-privilege base-pilot USER role."""

from __future__ import annotations

import getpass
import ipaddress
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable


ROLE_PROFILE = {
    "AGENTS": {"USE": True, "CREATE": False, "SHARE": False, "SHARE_PUBLIC": False},
    "MCP_SERVERS": {
        "USE": False,
        "CREATE": False,
        "SHARE": False,
        "SHARE_PUBLIC": False,
        "CONFIGURE_OBO": False,
    },
    "SKILLS": {"USE": False, "CREATE": False, "SHARE": False, "SHARE_PUBLIC": False},
    "SCHEDULES": {"USE": False, "CREATE": False},
    "RUN_CODE": {"USE": False},
    "WEB_SEARCH": {"USE": False},
    "FILE_SEARCH": {"USE": True},
    "FILE_CITATIONS": {"USE": True},
}


class SetupError(Exception):
    """A safe-to-display setup error that excludes server response bodies."""


class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def validate_base_url(raw_url: str) -> str:
    parsed = urllib.parse.urlsplit(raw_url.strip())
    if parsed.scheme not in {"https", "http"} or not parsed.hostname:
        raise SetupError("Enter a complete HTTPS URL (HTTP is allowed only for loopback).")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise SetupError("The base URL cannot contain credentials, a query, or a fragment.")
    if parsed.path not in {"", "/"}:
        raise SetupError("Enter only the deployment origin, without a path.")

    if parsed.scheme == "http":
        hostname = parsed.hostname.rstrip(".").lower()
        is_loopback = hostname == "localhost" or hostname.endswith(".localhost")
        try:
            is_loopback = is_loopback or ipaddress.ip_address(hostname).is_loopback
        except ValueError:
            pass
        if not is_loopback:
            raise SetupError("Refusing to send an admin password over non-loopback HTTP.")

    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, "", "", "")).rstrip("/")


def _post_json(opener, url: str, payload: dict, origin: str) -> dict:
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Origin": origin,
            "Referer": f"{origin}/",
        },
    )
    return _send_json(opener, request, "Admin sign-in")


def _send_json(opener, request: urllib.request.Request, action: str) -> dict:
    try:
        with opener.open(request, timeout=15) as response:
            status = response.status
            raw = response.read(1024 * 1024)
    except urllib.error.HTTPError as error:
        raise SetupError(f"{action} was rejected (HTTP {error.code}); response details suppressed.") from None
    except (urllib.error.URLError, TimeoutError, OSError):
        raise SetupError(f"Could not reach the deployment for {action.lower()}.") from None

    if not 200 <= status < 300:
        raise SetupError(f"{action} failed (HTTP {status}); response details suppressed.")
    try:
        result = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise SetupError(f"{action} returned an invalid response.") from None
    if not isinstance(result, dict):
        raise SetupError(f"{action} returned an unexpected response.")
    return result


def _matches_profile(actual: object) -> bool:
    if not isinstance(actual, dict):
        return False
    for group, expected_permissions in ROLE_PROFILE.items():
        actual_permissions = actual.get(group)
        if not isinstance(actual_permissions, dict):
            return False
        for permission, expected in expected_permissions.items():
            if actual_permissions.get(permission) is not expected:
                return False
    return True


def configure_member_role(
    base_url: str,
    email: str,
    password: str,
    totp_prompt: Callable[[], str],
    opener=None,
) -> None:
    origin = validate_base_url(base_url)
    if opener is None:
        opener = urllib.request.build_opener(NoRedirectHandler())

    login = _post_json(
        opener,
        f"{origin}/api/auth/login",
        {"email": email, "password": password},
        origin,
    )
    if login.get("twoFAPending") is True:
        temp_token = login.get("tempToken")
        if not isinstance(temp_token, str) or not temp_token:
            raise SetupError("Two-factor sign-in did not return a usable challenge.")
        code = totp_prompt().strip()
        if not code:
            raise SetupError("No two-factor code was entered.")
        login = _post_json(
            opener,
            f"{origin}/api/auth/2fa/verify-temp",
            {"tempToken": temp_token, "token": code},
            origin,
        )

    bearer = login.get("token")
    if not isinstance(bearer, str) or not bearer:
        raise SetupError("Sign-in did not return an authenticated session; no role change was made.")

    request = urllib.request.Request(
        f"{origin}/api/admin/roles/USER/permissions",
        data=json.dumps({"permissions": ROLE_PROFILE}).encode("utf-8"),
        method="PATCH",
        headers={
            "Accept": "application/json",
            "Authorization": f"Bearer {bearer}",
            "Content-Type": "application/json",
        },
    )
    result = _send_json(opener, request, "USER role update")
    role = result.get("role")
    if not isinstance(role, dict) or not _matches_profile(role.get("permissions")):
        raise SetupError(
            "The server accepted the update but its returned USER permissions did not match the expected profile. "
            "Verify the USER role in Admin Settings before adding members."
        )


def main() -> int:
    print("Gombey AI base-pilot USER role setup")
    print("This signs in to the deployment you specify, applies the USER profile, and verifies the returned settings.")
    print("Credentials are prompted locally and are not saved or printed. Use the customer's ADMIN account.\n")
    try:
        base_url = validate_base_url(input("Deployment URL (origin only): "))
        email = input("ADMIN email: ").strip()
        if not email:
            raise SetupError("An ADMIN email is required.")
        password = getpass.getpass("ADMIN password: ")
        if not password:
            raise SetupError("An ADMIN password is required.")

        def prompt_totp() -> str:
            return getpass.getpass("Two-factor authenticator code: ")

        configure_member_role(base_url, email, password, prompt_totp)
        password = ""
        print("PASS: USER role is set and verified. ADMIN access was not changed.")
        print("Next: create one separate USER account and verify shared-agent view/use and private-chat separation.")
        return 0
    except (SetupError, KeyboardInterrupt, EOFError) as error:
        if isinstance(error, (KeyboardInterrupt, EOFError)):
            print("Cancelled; no completion was reported.", file=sys.stderr)
        else:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
