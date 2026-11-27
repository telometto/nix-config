"""Render vmauth's private configuration from systemd credentials.

Only public usernames, paths and the loopback backend URL are command arguments.
Passwords and the replacement upstream Authorization header exist only in memory
and a mode-0600 runtime file. Validate a candidate with the deployed vmauth before
atomically publishing it; never print validator output, which may contain secrets.
"""

import argparse
import base64
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit


def read_password(path):
    value = Path(path).read_bytes().decode("utf-8")
    # SOPS text files commonly have one final newline; the VM file flag also
    # strips it. Embedded newlines and ambiguous surrounding whitespace fail.
    if value.endswith("\n"):
        value = value[:-1]
        if value.endswith("\r"):
            value = value[:-1]
    if (
        not value
        or value.strip() != value
        or any(ord(char) < 32 or ord(char) == 127 for char in value)
        or any(
            0xFDD0 <= ord(char) <= 0xFDEF or ord(char) & 0xFFFF in (0xFFFE, 0xFFFF)
            for char in value
        )
    ):
        raise ValueError("invalid password file")
    return value


def read_passwords(paths):
    passwords = [read_password(path) for path in paths]
    if len(set(passwords)) != len(passwords):
        raise ValueError("role passwords must be distinct")
    return passwords


def render(args):
    usernames = (args.writer_username, args.query_username, args.backend_username)
    if len(set(usernames)) != 3 or any(
        re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", name) is None for name in usernames
    ):
        raise ValueError("invalid or overlapping usernames")
    backend = urlsplit(args.backend_url)
    if (
        backend.scheme != "http"
        or backend.hostname != "127.0.0.1"
        or backend.port is None
        or backend.username is not None
        or backend.password is not None
        or backend.path not in ("", "/")
        or backend.query
        or backend.fragment
    ):
        raise ValueError("invalid backend URL")
    output = Path(args.output)
    parent = output.parent.stat()
    if (
        not stat.S_ISDIR(parent.st_mode)
        or stat.S_IMODE(parent.st_mode) != 0o700
        or parent.st_uid != os.geteuid()
    ):
        raise ValueError("output directory must be private and owned by this user")
    credentials = Path(os.environ["CREDENTIALS_DIRECTORY"])
    writer_password, query_password, backend_password = read_passwords(
        [
            credentials / "writer-password",
            credentials / "query-password",
            credentials / "backend-password",
        ]
    )
    backend_token = base64.b64encode(
        f"{args.backend_username}:{backend_password}".encode()
    ).decode()
    headers = [f"Authorization: Basic {backend_token}"]
    config = {
        "users": [
            {
                "username": args.writer_username,
                "password": writer_password,
                "url_map": [
                    {
                        "src_paths": ["/api/v1/write"],
                        "url_prefix": args.backend_url,
                        "headers": headers,
                    }
                ],
            },
            {
                "username": args.query_username,
                "password": query_password,
                "url_map": [
                    {
                        "src_paths": [
                            "/api/v1/query",
                            "/api/v1/query_range",
                            "/api/v1/labels",
                            "/api/v1/label/[A-Za-z_][A-Za-z0-9_]*/values",
                            "/api/v1/series",
                            "/api/v1/metadata",
                            # Grafana datasource health/version detection.
                            "/api/v1/status/buildinfo",
                        ],
                        "url_prefix": args.backend_url,
                        "headers": headers,
                    }
                ],
            },
        ]
    }
    # JSON is a YAML subset. Escape '%' so vmauth's environment substitution
    # cannot interpret a literal %{NAME} inside a supplied password.
    # YAML does not accept JSON surrogate-pair escapes. Preserve astral UTF-8,
    # while escaping YAML-sensitive controls and Unicode line separators.
    encoded = json.dumps(config, ensure_ascii=False)
    encoded = (
        re.sub(
            r"[\x7f-\x9f\u2028\u2029]",
            lambda match: f"\\u{ord(match[0]):04x}",
            encoded,
        ).replace("%", "\\u0025")
        + "\n"
    )
    descriptor, candidate_name = tempfile.mkstemp(prefix=".auth-", dir=output.parent)
    candidate = Path(candidate_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            os.fchmod(stream.fileno(), 0o600)
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
        result = subprocess.run(
            [args.vmauth_bin, f"-auth.config={candidate}", "-dryRun"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=30,
        )
        if result.returncode != 0:
            raise ValueError("vmauth rejected the candidate configuration")
        os.replace(candidate, output)
    finally:
        candidate.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    validate = commands.add_parser("validate-password")
    validate.add_argument("paths", nargs="+")
    renderer = commands.add_parser("render")
    for name in (
        "writer-username",
        "query-username",
        "backend-username",
        "backend-url",
        "output",
        "vmauth-bin",
    ):
        renderer.add_argument(f"--{name}", required=True)
    args = parser.parse_args()
    try:
        if args.command == "validate-password":
            read_passwords(args.paths)
        else:
            render(args)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        # Neither passwords nor validation output belong in journald.
        print(
            "VictoriaMetrics credential configuration validation failed",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
