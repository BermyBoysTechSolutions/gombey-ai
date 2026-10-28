#!/usr/bin/env python3
"""Securely set the customer-owned RAG embeddings key for local staging."""

from __future__ import annotations

import getpass
import os
import stat
import sys
import tempfile
import warnings
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENV = ROOT / "deploy" / "customer" / ".env"
KEY_NAME = "RAG_OPENAI_API_KEY"
DISABLED_KEY = "REPLACE_WITH_CUSTOMER_OWNED_EMBEDDINGS_API_KEY"
PLACEHOLDERS = {
    "",
    "user_provided",
    "REPLACE_ME",
    "REPLACE_WITH_CUSTOMER_OWNED_EMBEDDINGS_API_KEY",
}


def _replace_env_key(env_path: Path, key: str, *, allow_placeholder: bool) -> None:
    """Atomically replace exactly one key in an owner-only regular env file."""
    if not key or (not allow_placeholder and key in PLACEHOLDERS) or key.strip() != key:
        raise ValueError("a non-placeholder key without surrounding whitespace is required")
    if "\n" in key or "\r" in key or "\x00" in key:
        raise ValueError("the key must be a single line")

    env_path = env_path.expanduser().absolute()
    source_stat = env_path.lstat()
    if not stat.S_ISREG(source_stat.st_mode) or stat.S_ISLNK(source_stat.st_mode):
        raise ValueError("the environment path must be a regular file, not a symlink")
    if stat.S_IMODE(source_stat.st_mode) != 0o600:
        raise ValueError("the environment file must have mode 600")
    if source_stat.st_uid != os.geteuid():
        raise ValueError("run as the owner of the environment file; do not use sudo")

    original = env_path.read_text(encoding="utf-8")
    lines = original.splitlines(keepends=True)
    key_indexes = [
        index
        for index, line in enumerate(lines)
        if line.partition("=")[0] == KEY_NAME
    ]
    if len(key_indexes) != 1:
        raise ValueError(f"expected exactly one {KEY_NAME} entry")

    index = key_indexes[0]
    old_line = lines[index]
    newline = "\r\n" if old_line.endswith("\r\n") else "\n" if old_line.endswith("\n") else ""
    lines[index] = f"{KEY_NAME}={key}{newline}"
    updated = "".join(lines).encode("utf-8")

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{env_path.name}.", suffix=".tmp", dir=env_path.parent
    )
    try:
        os.fchmod(descriptor, 0o600)
        os.fchown(descriptor, source_stat.st_uid, source_stat.st_gid)
        with os.fdopen(descriptor, "wb") as temporary:
            descriptor = -1
            temporary.write(updated)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_name, env_path)
        directory_fd = None
        try:
            directory_fd = os.open(env_path.parent, os.O_RDONLY)
            os.fsync(directory_fd)
        except OSError:
            # The atomic replacement has already happened; do not report
            # failure or imply rollback after a directory-fsync limitation.
            print(
                "Warning: the key file was updated, but directory sync was unavailable.",
                file=sys.stderr,
            )
        finally:
            if directory_fd is not None:
                try:
                    os.close(directory_fd)
                except OSError:
                    pass
    except Exception:
        if descriptor >= 0:
            os.close(descriptor)
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def update_env_key(env_path: Path, key: str) -> None:
    """Securely set a non-placeholder embeddings key."""
    _replace_env_key(env_path, key, allow_placeholder=False)


def disable_env_key(env_path: Path) -> None:
    """Remove the active key without reading or displaying its previous value."""
    _replace_env_key(env_path, DISABLED_KEY, allow_placeholder=True)


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--disable",
        action="store_true",
        help="replace the current embeddings key with the unconfigured placeholder",
    )
    args = parser.parse_args()
    env_path = Path(os.environ.get("GOMBEY_CUSTOMER_ENV_PATH", str(DEFAULT_ENV)))
    if not env_path.exists():
        print("Customer environment file not found; initialize the local staging config first.", file=sys.stderr)
        return 1
    if not args.disable and not sys.stdin.isatty():
        print("Run this command from an interactive terminal so key input stays hidden.", file=sys.stderr)
        return 1

    try:
        if args.disable:
            disable_env_key(env_path)
        else:
            print(
                "Enter a newly rotated, customer-owned embeddings API key. "
                "Input is hidden and the value will not be displayed."
            )
            with warnings.catch_warnings():
                # getpass otherwise falls back to echoed stdin when /dev/tty is
                # unavailable; fail closed before reading any value in that case.
                warnings.simplefilter("error", getpass.GetPassWarning)
                key = getpass.getpass(f"{KEY_NAME}: ")
            update_env_key(env_path, key)
    except (EOFError, KeyboardInterrupt):
        print("\nNo changes made.", file=sys.stderr)
        return 1
    except getpass.GetPassWarning:
        print("No hidden-input terminal is available; no changes made.", file=sys.stderr)
        return 1
    except (OSError, ValueError) as error:
        print(f"Could not update the embeddings key: {error}", file=sys.stderr)
        return 1
    finally:
        if "key" in locals():
            key = ""

    if args.disable:
        print(f"Disabled {KEY_NAME}; placeholder restored. Restart only the staging RAG API to apply it.")
    else:
        print(f"Updated {KEY_NAME}; value hidden. Restart only the staging RAG API to apply it.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
