"""Refuse foreign runtime/credential paths or retained disks on a fresh cluster.

Only names, symlink targets, and existence are inspected; no credential or disk
contents are opened. Retained-volume adoption is a separate recovery operation.
"""

import json
import os
import sys
from pathlib import Path


def present(path):
    return path.exists() or path.is_symlink()


def nonempty(path):
    return present(path) and (
        path.is_symlink() or not path.is_dir() or any(path.iterdir())
    )


def claim(paths):
    state = Path(paths["stateDir"])
    if state.is_symlink():
        raise RuntimeError("pilot state must not be a symlink")
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    marker = state / "runtime-owner"
    owned = marker.is_file() and not marker.is_symlink()
    if not owned and any(state.iterdir()):
        raise RuntimeError("unowned nonempty pilot cluster state; refusing adoption")
    default = Path(paths["defaultKubeconfig"])
    if present(default) and not (
        owned
        and default.is_symlink()
        and os.readlink(default) == paths["pilotKubeconfig"]
    ):
        raise RuntimeError(
            "existing non-pilot default kubeconfig; preserve it before activation"
        )
    for filename in paths["absentAlways"]:
        if present(Path(filename)):
            raise RuntimeError("disabled pilot credential-provider path exists")
    if not owned:
        for filename in paths["firstStartFiles"]:
            if present(Path(filename)):
                raise RuntimeError(
                    "existing Kubernetes runtime or node credential; inspect ownership before activation"
                )
        for directory in paths["firstStartDirectories"]:
            if nonempty(Path(directory)):
                raise RuntimeError(
                    "existing shared Kubernetes device/CNI state; inspect ownership before activation"
                )
    fresh = not (state / "server/db/state.db").is_file()
    for directory in paths["diskDirs"]:
        path = Path(directory)
        if path.is_symlink() or (fresh and nonempty(path)):
            raise RuntimeError(
                "fresh cluster would import over retained pilot disks; use deliberate PVC recovery"
            )
    for directory in paths["diskDirs"]:
        Path(directory).mkdir(mode=0o700, parents=True, exist_ok=True)
    if not owned:
        descriptor = os.open(marker, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(descriptor)


if __name__ == "__main__":
    try:
        claim(json.loads(Path(sys.argv[1]).read_text()))
    except RuntimeError as error:
        raise SystemExit(f"Actual pilot preflight: {error}") from error
