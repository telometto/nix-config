import os
from pathlib import Path
import sys
import tempfile


path = Path(sys.argv[1])
server = sys.argv[2]
public_key = sys.stdin.read().strip()
if not public_key or any(character.isspace() for character in public_key):
    raise ValueError("RustDesk server public key must be one nonempty line")
if path.is_symlink():
    raise ValueError(f"Refusing to replace a symlink: {path}")

# This is a root-owned runtime file containing only a hostname and PUBLIC key.
# All RustDesk UIDs need read access; private identities stay in profiles.
temporary_path = None
try:
    with tempfile.NamedTemporaryFile(
        mode="w", dir=path.parent, prefix=".server-options-", delete=False
    ) as temporary:
        temporary_path = Path(temporary.name)
        temporary.write(f"{server}\n{public_key}\n")
    temporary_path.chmod(0o644)
    os.replace(temporary_path, path)
finally:
    if temporary_path is not None:
        temporary_path.unlink(missing_ok=True)
