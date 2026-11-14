"""Extract into a fresh private directory, preserving the original archive."""

import argparse
import bz2
import gzip
import lzma
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path, PurePosixPath, PureWindowsPath


def extract(source, bsdtar, gzip_program="gzip"):
    source = Path(source).resolve(strict=True)
    if not source.is_file():
        raise ValueError("Archive must be a regular file")
    destination = Path(tempfile.mkdtemp(prefix="extract-"))
    try:
        name = source.name
        suffix = source.suffix.lower()
        single = suffix in (".gz", ".bz2", ".xz", ".z") and not name.lower().endswith(
            (".tar.gz", ".tar.bz2", ".tar.xz")
        )
        if single:
            with (destination / source.stem).open("xb") as output:
                if suffix == ".z":
                    subprocess.run(
                        [gzip_program, "-cd", "--", str(source)],
                        stdout=output,
                        check=True,
                    )
                else:
                    opener = {".gz": gzip.open, ".bz2": bz2.open, ".xz": lzma.open}[
                        suffix
                    ]
                    with opener(source, "rb") as content:
                        shutil.copyfileobj(content, output)
        else:
            # Preserve unsafe names during conversion so the validation below
            # rejects them instead of silently rewriting them. Handles ZIP/7z too.
            with tempfile.TemporaryFile() as converted:
                subprocess.run(
                    [bsdtar, "-cPf", "-", "@" + str(source)],
                    stdout=converted,
                    check=True,
                )
                converted.seek(0)
                with tarfile.open(fileobj=converted) as archive:

                    def contained(member, target):
                        parts = PurePosixPath(member.name)
                        if (
                            parts.is_absolute()
                            or ".." in parts.parts
                            or PureWindowsPath(member.name).drive
                        ):
                            raise ValueError("Unsafe archive member path")
                        member = tarfile.data_filter(member, target)
                        path = destination / member.name
                        if path.exists() or path.is_symlink():
                            if not (
                                member.isdir()
                                and path.is_dir()
                                and not path.is_symlink()
                            ):
                                raise ValueError(
                                    "Archive member would overwrite another member"
                                )
                        return member

                    archive.extractall(destination, filter=contained)
        return destination
    except BaseException:
        shutil.rmtree(destination)
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bsdtar", required=True)
    parser.add_argument("--gzip", default="gzip")
    parser.add_argument("archive")
    args = parser.parse_args()
    try:
        print(extract(args.archive, args.bsdtar, args.gzip))
    except (
        ValueError,
        OSError,
        tarfile.TarError,
        subprocess.CalledProcessError,
    ) as error:
        parser.exit(1, f"Extraction refused: {error}\n")
