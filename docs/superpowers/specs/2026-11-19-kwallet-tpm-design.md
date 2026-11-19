# TPM-backed KWallet unlocking

## Intent and authorization

Keep SDDM automatic login and a password-encrypted `kdewallet`. Build a reusable
`sys.security.kwalletTpm` module and enable it for Gianluca on Kaizer. The user
authorized implementation, branch push and an unmerged PR, and will enroll the
password locally. Do not access real wallets, salts, encrypted credentials,
private inputs or other secrets; do not deploy or add co-author attribution.

## Approaches

A desktop unlock daemon would depend on changing private KWallet startup APIs.
The implementation choice is a PAM bridge: feed a TPM-protected password to
KDE's existing authentication hook, leaving wallet formats and daemon startup
to KDE. This supports Kaizer's KWallet 6.26 and avoids a package upgrade.
An empty wallet password already avoids prompts but lacks the requested
password protection.

## Reusable interface

`enable` defaults to false; `users` is an explicit list of local normal users.
`pcrs` defaults to `[ 4 7 ]` and must include 4 and 7; extra PCRs are advanced
configuration. Support Plasma 6 with SDDM automatic login. Install
`kwallet-tpm-enroll USER`. Credentials are per user under root-owned
`/var/lib/kwallet-tpm` (0700), with file mode 0600. Only public usernames,
policy and executable paths enter the Nix store.

## PAM boundary

Only `sddm-autologin` receives three adjacent authentication rules, ordered
relative to its existing required permit rule: inject the credential; invoke
KDE's wallet auth hook only after successful injection; clear the injected
token. Preserve any pre-existing token. A missing credential or failed,
malformed, oversized or timed-out decrypt skips the wallet hook without
prompting or changing the login decision. KDE's inherited session hook handles
startup. The compiled bridge bounds output/time, excludes its buffer from core
dumps, and wipes its temporary plaintext buffer and clears PAM_AUTHTOK. KDE keeps its
own password copy for the session hook. Normal password login remains unchanged.

## Local enrollment and recovery

First restore a nonempty password in KWallet Manager; a distinct wallet-only
password is recommended. Enrollment requires an interactive root terminal,
an allowlisted normal user, a usable TPM 2.0, Secure Boot enabled, and the active
generation already booted. Prompt twice, refuse empty/mismatched passwords,
and call `systemd-creds encrypt` with explicit `host+tpm2` and PCR binding.
Atomically replace the credential with private permissions; failures before
replacement leave the old credential intact. Never place plaintext in argv, environment or logs.

PCR 4 binds booted executable measurements, and PCR 7 binds Secure Boot policy.
Boot/kernel updates can require local re-enrollment after booting the intended
generation. Never automatically reseal after a policy failure. A stale password,
firmware update, TPM reset or motherboard replacement falls back to the manual
wallet password; do not modify the wallet or user login password.

## Security limits

TPM and matching measurements protect the encrypted unlock credential. This
does not authenticate whoever reaches the automatically logged-in desktop,
protect against root compromise, or prove the mutable root filesystem has
been measured. Secure Boot's enabled flag alone does not establish the whole
trust chain. Enrollment cannot verify a wallet password without opening the
wallet, so the user must verify it locally before enrollment.

## Verification and rollout

Use synthetic fixtures only. Exercise the actual Linux PAM stack with the
compiled bridge, fake decryptor and wallet observer: success, missing/bad
credentials, empty/NUL/oversized output, nonzero exit and timeout, existing
tokens, unauthorized users/services, token cleanup and denied login. Test
enrollment with injected prompts and fake systemd tools. Evaluate enabled,
disabled and another-host module cases using only locked public nixpkgs.
Add a flake check and run scoped formatting/static checks. Independently
review the finished branch. Live enrollment, TPM sealing, wallet access,
activation and reboot acceptance are left to the user.

The authenticated credential name includes the canonical configured PCR set.
A policy change invalidates older enrollment. An orphaned worker owns and reaps
the TPM decryptor; PAM cancels it via a pidfd without waiting for TPM cleanup.
