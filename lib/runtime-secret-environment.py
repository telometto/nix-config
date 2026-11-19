"""Render a runtime secret for both systemd EnvironmentFile and shell readers."""

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path


def render(variable, source, destination, *, json_scalar=False):
    if not re.fullmatch(r"[A-Z][A-Z0-9_]*", variable):
        raise ValueError("Invalid environment variable name")
    value = Path(source).read_text().removesuffix("\n").removesuffix("\r")
    if not value or any(char in value for char in "\n\r\0"):
        raise ValueError("Secret must be a nonempty single line")
    if json_scalar:
        # JSON strings are YAML scalars. Searx's envsubst inserts this value
        # into an unquoted YAML placeholder, after EnvironmentFile parsing.
        value = json.dumps(value)
    for char in ("\\", '"', "$", "`"):
        value = value.replace(char, "\\" + char)
    destination = Path(destination)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", dir=destination.parent, prefix=".environment-", delete=False
        ) as output:
            temporary = output.name
            output.write(f'{variable}="{value}"\n')
            output.flush()
            os.fchmod(output.fileno(), 0o640)
            os.fsync(output.fileno())
        os.replace(temporary, destination)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json-scalar", action="store_true")
    parser.add_argument("variable")
    parser.add_argument("source")
    parser.add_argument("destination")
    args = parser.parse_args()
    try:
        render(
            args.variable, args.source, args.destination, json_scalar=args.json_scalar
        )
    except (ValueError, OSError, UnicodeError):
        sys.exit("Cannot render runtime secret environment")
