"""Validate OpenSSH's effective scan settings and the dedicated key file."""

from pathlib import Path
import json
import sys


def main(effective_path, keys_path, target, scanner, port, declared_keys_path):
    settings = {}
    for line in Path(effective_path).read_text().splitlines():
        key, _, value = line.partition(" ")
        settings[key.lower()] = value
    expected = {
        "addressfamily": "inet",
        "port": str(port),
        "listenaddress": f"{target}:{port}",
        "allowusers": f"sandfly@{scanner}",
        "authenticationmethods": "publickey",
        "pubkeyauthentication": "yes",
        "authorizedkeysfile": "/etc/ssh/sandfly-authorized_keys",
        "authorizedkeyscommand": "none",
        "trustedusercakeys": "none",
        "passwordauthentication": "no",
        "kbdinteractiveauthentication": "no",
        "permitrootlogin": "no",
        "usepam": "yes",
        "strictmodes": "yes",
        "disableforwarding": "yes",
        "permittunnel": "no",
        "permituserrc": "no",
        "permituserenvironment": "no",
        "forcecommand": "none",
        "subsystem": "sftp internal-sftp",
    }
    for key, value in expected.items():
        assert settings.get(key) == value, (key, settings.get(key), value)
    keys = Path(keys_path).read_text().splitlines()
    declared_keys = json.loads(Path(declared_keys_path).read_text())
    assert declared_keys, "At least one scanner key must be declared"
    restrictions = (
        f'from="{scanner}",no-agent-forwarding,no-port-forwarding,'
        "no-X11-forwarding,no-user-rc "
    )
    assert keys == [restrictions + key for key in declared_keys], (
        "Rendered scanner keys must match every declared key and its restrictions"
    )


if __name__ == "__main__":
    main(*sys.argv[1:])
