"""Enroll a wallet password locally. Never open or modify the wallet itself."""

import argparse
import getpass
import json
import os
import pwd
import re
import resource
import secrets
import stat
import subprocess
import sys
import warnings
from pathlib import Path

CONFIG_FILE = "@config@"
SECURE_BOOT = Path(
    "/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"
)
MAX_PASSWORD = 4096
MAX_CIPHERTEXT = 65536


class EnrollmentError(Exception):
    pass


def validate(username, config):
    if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_.-]*\$?", username):
        raise EnrollmentError("Invalid local username.")
    if username not in config["users"]:
        raise EnrollmentError("User is not enabled in sys.security.kwalletTpm.users.")
    pcrs = config["pcrs"]
    if (
        not isinstance(pcrs, list)
        or not {4, 7}.issubset(pcrs)
        or any(type(pcr) is not int or not 0 <= pcr <= 23 for pcr in pcrs)
    ):
        raise EnrollmentError(
            "The PCR policy must include PCRs 4 and 7 and valid indexes."
        )


def preflight(username, config):
    if os.geteuid() != 0:
        raise EnrollmentError("Run enrollment locally with sudo.")
    if not sys.stdin.isatty():
        raise EnrollmentError("Enrollment requires an interactive terminal.")
    try:
        if pwd.getpwnam(username).pw_uid == 0:
            raise EnrollmentError("Root wallets are not supported.")
        boot = SECURE_BOOT.read_bytes()
        if len(boot) != 5 or boot[4] != 1:
            raise EnrollmentError("Secure Boot must be enabled before enrollment.")
        if Path("/run/current-system").resolve(strict=True) != Path(
            "/run/booted-system"
        ).resolve(strict=True):
            raise EnrollmentError("Reboot into the active generation before enrolling.")
        result = subprocess.run(
            [config["systemdAnalyze"], "has-tpm2", "--quiet"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
            check=False,
        )
        if result.returncode != 0:
            raise EnrollmentError("A fully usable TPM 2.0 is required.")
    except (OSError, KeyError, subprocess.SubprocessError) as error:
        raise EnrollmentError(
            "Could not verify local TPM and boot prerequisites."
        ) from error


def private_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        info = os.fstat(fd)
    except OSError:
        os.close(fd)
        raise
    if info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o700:
        os.close(fd)
        raise EnrollmentError("Credential directory must be root-owned with mode 0700.")
    return fd


def enroll(username, config, *, prompt=getpass.getpass):
    validate(username, config)
    preflight(username, config)
    directory = Path(config["credentialDirectory"])
    fd = -1
    temporary = None
    try:
        fd = private_directory(directory)
        filename = username + ".cred"
        try:
            previous = os.stat(filename, dir_fd=fd, follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            if (
                not stat.S_ISREG(previous.st_mode)
                or previous.st_uid != os.geteuid()
                or stat.S_IMODE(previous.st_mode) != 0o600
                or previous.st_nlink != 1
            ):
                raise EnrollmentError(
                    "Existing credential has unsafe type or permissions."
                )
        first = prompt(
            "KWallet password (set a nonempty password in KWallet Manager first): "
        )
        second = prompt("Confirm KWallet password: ")
        password = first.encode("utf-8")
        if not password or first != second:
            raise EnrollmentError("Passwords must be nonempty and match.")
        if len(password) > MAX_PASSWORD or b"\0" in password:
            raise EnrollmentError(
                "Password is too long or contains an unsupported NUL byte."
            )
        try:
            result = subprocess.run(
                [
                    config["systemdCreds"],
                    "encrypt",
                    "--with-key=host+tpm2",
                    "--tpm2-device=auto",
                    "--tpm2-pcrs=" + "+".join(map(str, sorted(set(config["pcrs"])))),
                    "--name=kwallet-tpm-"
                    + username
                    + "-pcr-"
                    + "_".join(map(str, sorted(set(config["pcrs"])))),
                    "-",
                    "-",
                ],
                input=password,
                capture_output=True,
                env={"LC_ALL": "C", "SYSTEMD_LOG_LEVEL": "err"},
                timeout=30,
                check=False,
            )
        except (OSError, subprocess.SubprocessError) as error:
            raise EnrollmentError(
                "TPM encryption failed; credential was not replaced."
            ) from error
        finally:
            del first, second, password
        if result.returncode != 0 or not 0 < len(result.stdout) <= MAX_CIPHERTEXT:
            raise EnrollmentError("TPM encryption failed; credential was not replaced.")
        temporary = "." + username + "." + secrets.token_hex(12) + ".tmp"
        out = os.open(
            temporary,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
            0o600,
            dir_fd=fd,
        )
        with os.fdopen(out, "wb") as stream:
            os.fchmod(stream.fileno(), 0o600)
            stream.write(result.stdout)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, filename, src_dir_fd=fd, dst_dir_fd=fd)
        temporary = None
        # Replacement is the commit point: do not report that the old credential
        # survived if a later directory sync fails.
        try:
            os.fsync(fd)
        except OSError:
            print(
                "Credential replaced; directory durability could not be confirmed.",
                file=sys.stderr,
            )
    except OSError as error:
        raise EnrollmentError(
            "Could not write a private credential; enrollment failed."
        ) from error
    finally:
        if fd >= 0:
            if temporary is not None:
                try:
                    os.unlink(temporary, dir_fd=fd)
                except FileNotFoundError:
                    pass
            os.close(fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "user", help="local user enabled in sys.security.kwalletTpm.users"
    )
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    warnings.simplefilter("error", getpass.GetPassWarning)
    try:
        config = json.loads(Path(CONFIG_FILE).read_text())
        enroll(args.user, config)
    except (EnrollmentError, OSError, ValueError) as error:
        message = (
            str(error) if isinstance(error, EnrollmentError) else "Enrollment failed."
        )
        print(message, file=sys.stderr)
        return 1
    except getpass.GetPassWarning:
        print("Could not disable terminal echo; enrollment cancelled.", file=sys.stderr)
        return 1
    except (EOFError, KeyboardInterrupt):
        print("Enrollment interrupted; rerun enrollment if needed.", file=sys.stderr)
        return 1
    print(
        f"Enrolled TPM KWallet unlocking for {args.user}; test at the next automatic login."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
