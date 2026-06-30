# Credential Lifecycle

This is the pragmatic security posture for this flake and the private
`nix-secrets` repository. The goal is to make stale or risky credentials easy
to see without turning routine maintenance into lockout roulette.

The baseline is:

1. Use strong, unique credentials.
1. Do not force routine human password expiry.
1. Rotate after compromise, ownership changes, device loss, provider expiry, or
   a planned algorithm upgrade.
1. Automate checks and reminders before automating replacement.

This follows the current password direction from NIST and NCSC: length,
screening, rate limiting, and MFA matter more than periodic password churn.
Forced expiry often trains users to pick predictable variants. For this repo,
blind rotation is especially risky because `users.mutableUsers = false` and a
bad `hashedPassword` or SSH key change can lock a real account out on rebuild.

## Credential Classes

| Class | Storage | Rotation policy | Notes |
|---|---|---|---|
| Human login passwords | Bitwarden, with hashes in private `vars.nix` | Rotate on risk events only | Used for console login, sudo, and desktop unlock. SSH password login stays disabled. |
| SSH user keys | Private key on the owning device or hardware token; public key in `vars.nix` | Review quarterly; rotate on device loss, private-key exposure, offboarding, or weak key type | Prefer one key per device or purpose. Use Ed25519 or FIDO2 `ed25519-sk` where practical. |
| GPG SSH keys | GPG auth subkey, preferably hardware-backed | Renew or replace deliberately | Do not silently rotate auth subkeys unless every consuming host and service is updated. |
| Host SSH keys used by `sops-nix` | Host filesystem; age recipient in `nix-secrets/.sops.yaml` | Rotate on reimage, compromise, persistent storage loss, or algorithm upgrade | Treat these as infrastructure identity. Do not rotate casually. |
| API tokens | SOPS, provider console, and Bitwarden as appropriate | Rotate on provider expiry, suspected exposure, broad privilege, or service-owner change | Prefer scoped tokens and provider-supported dual-token rollover. |
| WireGuard keys | SOPS or host-specific private storage | Rotate on device loss, peer removal, or key exposure | Coordinate peer config before removing the old key. |
| Backup and encryption passphrases | Bitwarden and/or offline recovery material | Avoid routine rotation unless migration is tested | Restore reliability is more important than arbitrary churn. |
| Service secrets | SOPS runtime files | Rotate only with a restart/reload and rollback path | Session, signing, and encryption keys can invalidate users or data if changed blindly. |

## Private `vars.nix` Guidance

`hashedPassword` is sensitive hash material. It is not plaintext, but it is
still offline-crackable if exposed, so keep it only in the private
`nix-secrets` repo and do not copy it into this public flake.

The existing user shape remains valid. Optional metadata can be added in
`nix-secrets` when it is useful for review:

```nix
zeno = makeUser {
  credentialMeta = {
    created = "2026-06-30";
    reviewAfter = "2026-09-30";
    purpose = "primary personal account";
    owner = "zeno";
    storage = "bitwarden"; # bitwarden | hardware-key | disk-passphrase
    rotation = "manual-review"; # on-compromise | provider-expiry | manual-review
  };
};
```

This metadata is advisory. The public flake should not require it, because old
`vars.nix` revisions and emergency rebuilds should continue to evaluate.

## Review Checklist

Run this quarterly, or after a lost device, suspicious login, service owner
change, or secret scanning alert:

1. Confirm each enabled user still needs access on each host.
1. Confirm each SSH public key has a known owner, device, and purpose.
1. Remove keys for retired devices before adding new ones.
1. Check Bitwarden for reused, weak, or exposed passwords.
1. Check provider consoles for stale API tokens and tokens without last-used
   activity.
1. Confirm SOPS recipients still map to real active hosts.
1. Rebuild one low-risk host after changing account credentials before rolling
   the same pattern further.

## Human Password Runbook

Use this only for compromise, suspected reuse, weak password discovery, account
ownership change, or a deliberate annual/quarterly review decision. Do not run
it just because a timer fired.

1. Generate a new unique password in Bitwarden.
1. Create a Nix-compatible hash, for example:

   ```bash
   nix run nixpkgs#mkpasswd -- -m yescrypt
   ```

1. Update only the matching `hashedPassword` in private `nix-secrets/vars.nix`.
1. Rebuild a non-critical host where the account is enabled.
1. Test console login, sudo, and desktop unlock.
1. Rebuild the remaining affected hosts.

## SSH User Key Runbook

Use one key per device or purpose. For disk-backed keys, use a passphrase. For
admin paths where usability allows it, prefer FIDO2 security-key backed keys.

1. Generate the replacement key on the owning device.
1. Add the new public key to `vars.nix` while keeping the old key.
1. Rebuild one host and verify login with the new key.
1. Rebuild all affected hosts.
1. Remove the old public key from `vars.nix`.
1. Rebuild again and verify the old key no longer works.

## Service Secret Runbook

Only rotate service secrets when the service supports it or when the risk
justifies downtime.

1. Identify every consumer of the SOPS key and whether it supports dual-secret
   rollover.
1. Generate the new secret into Bitwarden or the provider console first, then
   update the encrypted SOPS value.
1. Rebuild or restart only the dependent service.
1. Verify health and authentication behavior.
1. Remove the old credential after the new one is confirmed.

## Sources

- [NIST SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html)
- [CyberUnit summary of the NIST password update](https://cyberunit.com/insights/nist-password-guidelines-2026-update/)
- [NCSC: The problems with forcing regular password expiry](https://www.ncsc.gov.uk/blog-post/problems-forcing-regular-password-expiry)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [OpenSSH ssh-keygen manual](https://man.openbsd.org/ssh-keygen.1)
- [GitHub: Reviewing your SSH keys](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/reviewing-your-ssh-keys)
