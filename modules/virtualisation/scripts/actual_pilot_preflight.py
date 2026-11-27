"""Refuse foreign runtime/credential paths or retained disks on a fresh cluster.

Only names, symlink targets, and existence are inspected; no credential or disk
contents are opened. Retained-volume adoption is a separate recovery operation.
"""

import hashlib
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


def reject_symlinks(path):
    if any(part.is_symlink() for part in (path, *path.parents)):
        raise RuntimeError("pilot state and disk paths must not contain a symlink")


def private_mkdir(path):
    # Path.mkdir(parents=True) applies mode only to the last component.
    for parent in reversed((path, *path.parents)):
        if not parent.exists():
            parent.mkdir(mode=0o700)


def claim(paths):
    state = Path(paths["stateDir"])
    reject_symlinks(state)
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
    preview_dirs = set(paths.get("previewDiskDirs", []))
    if not preview_dirs.issubset(paths["diskDirs"]):
        raise RuntimeError("preview registration must name a declared disk directory")
    registrations = state / "preview-disk-owners"
    if preview_dirs:
        reject_symlinks(registrations)
        if present(registrations) and not registrations.is_dir():
            raise RuntimeError("invalid preview registration directory")
    new_records = []
    fresh = not (state / "server/db/state.db").is_file()
    for directory in paths["diskDirs"]:
        path = Path(directory)
        reject_symlinks(path)
        if fresh and nonempty(path):
            raise RuntimeError(
                "fresh cluster would import over retained pilot disks; use deliberate PVC recovery"
            )
        if directory in preview_dirs:
            record = registrations / hashlib.sha256(directory.encode()).hexdigest()
            if present(record):
                if record.is_symlink() or not record.is_file():
                    raise RuntimeError("invalid preview disk registration")
            else:
                if nonempty(path):
                    raise RuntimeError(
                        "unregistered preview directory is nonempty; refusing adoption"
                    )
                new_records.append(record)
    # Validate the whole declaration before creating directories or records.
    for directory in paths["diskDirs"]:
        private_mkdir(Path(directory))
    if preview_dirs:
        private_mkdir(registrations)
    for record in new_records:
        descriptor = os.open(record, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(descriptor)
    if not owned:
        descriptor = os.open(marker, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(descriptor)


if __name__ == "__main__":
    try:
        claim(json.loads(Path(sys.argv[1]).read_text()))
    except RuntimeError as error:
        raise SystemExit(f"Actual pilot preflight: {error}") from error
