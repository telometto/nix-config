import json
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


for name, fixture in json.loads(Path(sys.argv[1]).read_text()).items():
    script = Path(fixture["script"]).read_text()
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        user = "fixture-user"
        password = "fixture-password =!?$"
        (root / "user").write_text(user + "\n")
        (root / "password").write_text(password + "\n")
        output = root / "credentials.env"
        assert user not in script and password not in script
        rendered = script.replace("/fixture/", str(root) + "/").replace(
            f"/run/{name}/credentials.env", str(output)
        )
        executable = root / "render-credentials"
        executable.write_text(rendered)
        executable.chmod(0o700)
        subprocess.run([str(executable)], check=True)
        assert output.read_text() == f"CUSTOM_USER={user}\nPASSWORD={password}\n"
        assert stat.S_IMODE(output.stat().st_mode) == 0o400
        # A restarted service gets a fresh RuntimeDirectory.
        (root / "password").write_text("rotated\n")
        output.unlink()
        subprocess.run([str(executable)], check=True)
        assert output.read_text() == f"CUSTOM_USER={user}\nPASSWORD=rotated\n"
        assert stat.S_IMODE(output.stat().st_mode) == 0o400

print("Both browser credential renderers passed temporary-fixture checks")
