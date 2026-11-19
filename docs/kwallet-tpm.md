# TPM-backed KWallet unlocking

The reusable `sys.security.kwalletTpm` module unlocks a password-encrypted
`kdewallet` during SDDM automatic login. Kaizer opts in for `gianluca`.
The module is off by default elsewhere. It uses KDE's existing
`pam_kwallet5.so` authentication and session handling, including Kaizer's
KWallet 6.26; it does not implement the wallet format or run another wallet daemon.

## What it protects

The wallet keeps a nonempty password. A separate copy of that password is
encrypted with `systemd-creds` using **both** the host key and TPM 2.0, and
is bound to explicit boot measurements. The default policy uses PCR 4 (boot
executables) and PCR 7 (Secure Boot policy). There is no host-only or unbound
fallback. The credential is stored locally as
`/var/lib/kwallet-tpm/USER.cred`, root-owned mode 0600 inside a mode-0700
directory. Nothing secret belongs in the repository, Nix options or Nix store.

This does **not** authenticate whoever is using the automatically logged-in
desktop. Anyone who can boot the enrolled system and reach that desktop can use
its unlocked wallet. It does not protect against root compromise or establish
that the whole writable root filesystem has been measured. Secure Boot's
enabled flag alone does not establish the complete trust chain. Copying the
encrypted credential to another machine does not provide the original TPM.

## Enroll locally on Kaizer

These are user-run steps after you choose to deploy the configuration.
Development, PR creation and CI do not deploy it or enroll a password.

1. Deploy through your normal reviewed process and **reboot into the active
   generation before enrollment**. The helper refuses enrollment if
   `/run/current-system` differs from `/run/booted-system`.

1. In Gianluca's desktop, open **KWallet Manager**, select **kdewallet**, and use
   **Change Password** to restore a **nonempty** password. A separate wallet-only
   password is recommended. Leave the account/login password unchanged.
   This integration supports password-encrypted wallets, not GPG-encrypted ones.

1. Verify the new password locally by closing and reopening the wallet in
   KWallet Manager. The enrollment helper deliberately does not open the
   wallet and cannot check that the password you enter is correct.

1. Open a local terminal on Kaizer and run:

   ```console
   systemd-analyze has-tpm2
   sudo kwallet-tpm-enroll gianluca
   ```

   Enter the wallet password twice at the hidden prompts. The sudo prompt, if
   shown first, asks for your account password. Do not put either password in
   the command, a shell variable, a file, or a chat message.

1. Reboot or log out and let SDDM log Gianluca in automatically. Open an
   application that uses KWallet and confirm there is no unlock-password
   prompt. Application-access approval dialogs are separate from wallet
   password prompts.

Enrollment requires an interactive root terminal, an allowlisted non-root
account, usable TPM 2.0, Secure Boot enabled, and the active generation already
booted. An empty password, mismatched confirmation, TPM error or a failure
before atomic replacement leaves the previous credential unchanged. Passwords
are passed only through a private subprocess pipe, never command arguments or
environment variables. Helper diagnostics cannot echo the encryption program's
output or errors.

The encrypted credential is not your recovery password. Keep your wallet
password available through your normal private recovery arrangements. Do not
publish the credential or the systemd host credential key.

## Updates and recovery

PCR 4 can change with a different boot image/generation, kernel or bootloader;
PCR 7 can change with Secure Boot policy or firmware changes. Those changes can
stop automatic wallet unlocking. This is intentional: the module never
automatically reseals a credential after a policy mismatch.

After booting the intended new generation, unlock the wallet manually with its
known password, then run `sudo kwallet-tpm-enroll gianluca` locally again.
Use the same procedure after changing the wallet password. A TPM reset,
motherboard replacement, host-key loss, corrupt credential or incorrect
enrollment also leaves manual wallet unlocking available.

Missing enrollment and decrypt failure do not introduce a password prompt in
SDDM or change the login authentication decision. KDE may ask for the wallet
password when an application first needs the locked wallet.

To turn this feature off, remove the host opt-in or set
`sys.security.kwalletTpm.enable = false` and deploy through the usual process.
The module leaves the encrypted credential and wallet intact. Normal password
login and other PAM services do not use this TPM credential.

## Enable another host

For another Plasma 6 host using SDDM automatic login, add this to its
auto-loaded host configuration, replacing the example username:

```nix
{
  sys.security.kwalletTpm = {
    enable = true;
    users = [ "alice" ];
  };
}
```

The user must already be a local normal account and must match the host's
configured SDDM automatic-login user. Enroll separately on that host as that
user; do not copy Kaizer's credential. Each allowlisted user gets a distinct
credential. This module does not enable automatic login by itself.

`pcrs` can add indexes to the default `[ 4 7 ]`; removing 4 or 7 is
rejected. Extra measurements can change during boot or ordinary use, so
understand their lifecycle before adding them.

The module uses NixOS's **experimental** PAM rules API. Its shape and ordering
can change without notice on nixpkgs updates. Review the rendered PAM stack and
rerun the public regression check after such updates; incorrect PAM ordering
can lock users out or weaken authentication. The three added auth rules must
remain adjacent after SDDM's required permit rule. A configuration assertion
rejects an intervening rule.

## Validation boundaries

`tests/kwallet-tpm.nix` evaluates the module enabled, disabled and reused on a
second synthetic host without private inputs. It builds the production package
and runs synthetic enrollment and real Linux PAM control-flow tests. The
hermetic PAM fixture disables kernel audit transport; the audited PAM fixture
can also be run locally outside a restricted sandbox.

These checks do not enroll the real TPM, inspect a real wallet, prove complete
boot-chain integrity, deploy Kaizer or verify reboot acceptance. Those remain
the local steps above.

Upstream references:
[systemd encrypted credentials](https://www.freedesktop.org/software/systemd/man/latest/systemd-creds.html),
[TPM PCR definitions](https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html),
[KDE's PAM integration](https://invent.kde.org/plasma/kwallet-pam).
