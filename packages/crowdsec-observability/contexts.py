"""Remove only obsolete Nix-generated context links, never arbitrary files."""

import json
import os
from pathlib import Path
import re
import sys


def clean(directory, keep):
    for path in Path(directory).iterdir():
        if not path.is_symlink():
            continue
        target = os.readlink(path)
        if re.fullmatch(r"/nix/store/[a-z0-9]{32}-context\.yaml", target):
            if target not in keep and path.name == Path(target).name:
                path.unlink()


if __name__ == "__main__":
    clean(sys.argv[1], json.loads(Path(sys.argv[2]).read_text()))
