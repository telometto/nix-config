"""Validate OpenSSH's effective scan settings and the dedicated key file."""

from pathlib import Path
import sys


def main(effective_path, keys_path, target, scanner):
    settings = {}
    for line in Path(effective_path).read_text().splitlines():
        key, _, value = line.partition(" ")
        settings[key.lower()] = value
    expected = {
        "addressfamily": "inet",
        "port": "2222",
        "listenaddress": f"{target}:2222",
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
    assert len(keys) == 1
    assert keys[0].startswith(
        f'from="{scanner}",no-agent-forwarding,no-port-forwarding,'
        "no-X11-forwarding,no-user-rc ssh-ed25519 "
    )


if __name__ == "__main__":
    main(*sys.argv[1:])
