#!/usr/bin/env python3
"""Refresh Flutter Git hashes after replacing pubspec.lock.json from pinned source.

Run on Linux with nix-prefetch-git and nix on PATH. Never resolves branch tips:
each fetch uses the full resolved-ref from the upstream lockfile.
"""

import json
from pathlib import Path
import subprocess


def main():
    package_dir = Path(__file__).resolve().parent
    packages = json.loads((package_dir / "pubspec.lock.json").read_text())["packages"]
    hashes = {}
    for name, package in sorted(packages.items()):
        if package["source"] != "git":
            continue
        description = package["description"]
        result = subprocess.run(
            [
                "nix-prefetch-git",
                "--url",
                description["url"],
                "--rev",
                description["resolved-ref"],
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=600,
        )
        hashes[name] = json.loads(result.stdout)["hash"]
        print(name, hashes[name], flush=True)
    (package_dir / "git-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n")


if __name__ == "__main__":
    main()
