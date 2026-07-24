# Immich OAuth Operations

Immich uses Pocket ID as an OpenID Connect (OIDC) provider at:

```text
Issuer: https://id.<public-domain>
Application: https://photos.<public-domain>
```

The checked-in configuration uses Pocket ID as the sole interactive login
authority. Automatic registration and automatic OAuth launch are enabled, and
Immich password login is disabled. Pocket ID's per-client allowed group is the
admission boundary: creating a Pocket ID account does not by itself grant
access to Immich.

______________________________________________________________________

## Identity and admission model

The pinned Immich 2.7.5 release first looks up an OAuth identity by its stable
OIDC `sub`. If no identity is linked, it can match an existing Immich account
by email and link it before applying the `autoRegister` setting. It does not
require the OIDC `email_verified` claim for that match.

Pocket ID does not verify email in this deployment because SMTP is not
configured. Email is nevertheless required to create a new Immich account.
The deployment therefore treats group membership, not the email claim, as the
authorization decision and enforces all of the following:

- The Immich OIDC client is restricted to a reviewed Pocket ID group.
- Pocket ID signup requires an administrator-issued token and grants no groups
  by default.
- Every account that existed in Immich before passwordless mode was linked to
  its intended Pocket ID identity.
- Administrators do not manually pre-create future Immich accounts.
- The Immich client requests `openid email profile` and creates an account
  only on the first login of a user admitted by the allowed group.
- Linked users are resolved by stable OIDC `sub` before their editable email
  is considered.
- Immich password login remains disabled.

An unlinked, manually pre-created Immich account would reintroduce the unsafe
email-linking path. Do not create one while this model is active. If migration
or recovery creates an unlinked account, remove its prospective user from the
allowed group and follow the controlled linking procedure below before
restoring access.

______________________________________________________________________

## Provision the Pocket ID client

The Pocket ID client is external state. Its authoritative contract is shared
between Pocket ID, `vms/immich.nix`, and the SOPS key
`immich/oauth_client_secret`.

1. In Pocket ID, create a dedicated group such as `immich-users`.
1. Review every member through a trusted identity channel. Do not use a
   matching email address as proof that two accounts belong to the same person.
1. Create a confidential OIDC client named `Immich`.
1. Register these exact callback URLs:

   ```text
   https://photos.<public-domain>/auth/login
   https://photos.<public-domain>/user-settings
   app.immich:///oauth-callback
   ```

1. Under **Allowed User Groups**, select only the reviewed Immich group. Do
   not make the client unrestricted.
1. Confirm that the generated client ID exactly matches
   `oauthClientId` in `vms/immich.nix`. Pocket ID assigns this value; if the
   client is recreated, update the Nix value and its SOPS secret together.
1. Store the generated secret at `immich/oauth_client_secret` in the private
   `nix-secrets` flake. Never commit the secret to this repository.

The configured OIDC parameters are:

```text
Scopes: openid email profile
ID token signing algorithm: RS256
Userinfo signing algorithm: none
Token endpoint authentication: client_secret_post
```

The actual scope is `openid email profile`. Immich requires the email claim
when automatically creating an account. The claim is profile data, not the
authorization control: Pocket ID must first admit the user through the
client's reviewed allowed group.

The mobile custom-scheme callback is required by the Immich apps. If Pocket ID
ever stops accepting it, use Immich's HTTPS
`https://photos.<public-domain>/api/oauth/mobile-redirect` override and update
both the Pocket ID callback list and Immich configuration in the same change.

______________________________________________________________________

## Bootstrap the SOPS secret

The Immich VM must already have its persistent SSH host key registered as a
SOPS age recipient. Follow the [SOPS Setup Guide](sops-setup-guide.md) if it
does not.

In the private `nix-secrets` repository:

1. Add the generated Pocket ID client secret at
   `immich/oauth_client_secret`.
1. Run `sops updatekeys` for the affected encrypted file.
1. Commit and push the private change.

Then refresh the locked private input and deploy from a Nix-capable machine:

```bash
nix flake update nix-secrets
sudo nixos-rebuild switch --flake .#blizzard
```

Inside the Immich VM, confirm that secret installation completed before the
server became active:

```bash
systemctl is-active sops-install-secrets.service
systemctl is-active immich-server.service
systemctl show immich-server.service \
  --property=After \
  --property=Requires \
  --property=ActiveEnterTimestamp
```

`immich-server.service` requires and starts after
`sops-install-secrets.service`. This ordering is required because sops-nix
queues `restartUnits` before atomically switching the `/run/secrets` symlink;
without the ordering, systemd can snapshot the previous client secret during
rotation.

______________________________________________________________________

## Link an existing account safely

All accounts that existed before passwordless mode were linked and tested.
Use this maintenance procedure only if a restore or migration introduces an
unlinked Immich account:

1. Remove the Pocket ID user from the Immich client's allowed group.
1. Temporarily set `passwordLogin.enabled = true` and `autoLaunch = false`,
   deploy the change, and limit the maintenance window.
1. In Immich administration, inventory the account's current email.
1. In Pocket ID, verify the intended person's identity and group membership.
   Do not use email equality as proof that the accounts belong to the same
   person.
1. Have the user sign in to Immich with a temporary local credential delivered
   through a trusted channel.
1. Only after that authenticated Immich session is active, add the Pocket ID
   user to the restricted Immich group.
1. Open **Account Settings**, then **OAuth**, and link the Pocket ID identity
   from that authenticated session.
1. Restore `passwordLogin.enabled = false` and `autoLaunch = true`, deploy, and
   confirm that local password login is rejected.
1. Sign out and confirm that **Login with Pocket ID** returns the same Immich
   account, library, and role.
1. Test the mobile app with the same non-administrator account.

Do not use a direct OAuth login for an unlinked existing account. Immich can
match it by an unverified or self-selected email before applying
`autoRegister`; the authenticated settings flow establishes the intended
stable OIDC `sub` without using email as proof of identity.

### Onboard a new user

Automatic registration is the normal onboarding path:

1. Create the Pocket ID user or issue a short-lived, single-use signup token.
1. Have the user register their passkey and complete their Pocket ID profile.
   Signup alone must not assign the Immich group.
1. Review the intended user's identity, then add them to the restricted Immich
   group.
1. Do not create a corresponding account in Immich.
1. Have the user choose **Login with Pocket ID**. Their first approved login
   creates and links the Immich account.
1. Validate web and mobile OAuth login.

Removing a user from the allowed group prevents new Pocket ID authorization
for Immich, but does not necessarily terminate an already active Immich
session. For immediate revocation, also disable the Immich user or revoke its
sessions through Immich administration.

______________________________________________________________________

## Break-glass recovery

Pocket ID is the login-availability boundary. Protect its database, encryption
key, administrator passkeys, and documented snapshot/export recovery path.
Register an independent backup passkey for the Pocket ID administrator and
test the CLI one-time-access procedure before relying on passwordless Immich
login.

If a user loses every passkey while Pocket ID remains available, generate a
short-lived one-time access link from Pocket ID administration or its CLI.

If Pocket ID is unavailable:

1. Preserve any active Immich administrator session.
1. Inspect and restore Pocket ID using [Pocket ID Operations](pocket-id.md).
1. Verify Pocket ID discovery, an administrator login, and a non-admin Immich
   login before declaring recovery complete.
1. As a last resort only, temporarily set `passwordLogin.enabled = true` and
   `autoLaunch = false`, deploy, and use
   `https://photos.<public-domain>/auth/login?autoLaunch=0`.
1. Restore passwordless settings immediately after Pocket ID login succeeds.

______________________________________________________________________

## Rotate the OAuth client secret

Pocket ID client-secret regeneration can interrupt OAuth logins. Use a short
maintenance window:

1. Keep an active Immich administrator session and confirm Pocket ID
   administrator and console recovery access.
1. Regenerate the Immich client secret in Pocket ID.
1. Immediately replace `immich/oauth_client_secret` in `nix-secrets`, update
   the affected SOPS recipients, commit, and refresh the locked private input.
1. Deploy Blizzard. The SOPS restart request and explicit systemd ordering
   restart Immich only after the new secret generation is active.
1. Verify a non-admin web login and a mobile login.
1. Check `journalctl -u immich-server.service` for OIDC or credential errors.

If validation fails, use the active administrator session or roll back the
secret/configuration together. Do not make the client unrestricted, enable
insecure callbacks, or leave password login enabled to restore access.

______________________________________________________________________

## CSP ownership and upgrade check

Traefik deliberately does not inject its shared CSP on the Immich route.
Instead, `IMMICH_HELMET_FILE=true` enables the policy packaged with the pinned
Immich release, keeping frontend asset requirements and the policy in the same
release.

After every Immich upgrade:

1. Confirm that exactly one `Content-Security-Policy` header is returned:

   ```bash
   headers="$(mktemp)"
   curl --fail --silent --show-error \
     --dump-header "$headers" \
     --output /dev/null \
     https://photos.<public-domain>/
   grep -i '^content-security-policy:' "$headers"
   test "$(grep -ic '^content-security-policy:' "$headers")" -eq 1
   rm "$headers"
   ```

1. In a clean browser session, verify the login page, thumbnails, full images,
   map tiles, video playback, and an upload while checking the console for CSP
   violations.
1. Verify OAuth login and an upload from the mobile app.

If the header is absent, do not leave the service deployed without either
restoring Immich's packaged Helmet policy or adding a tested route-scoped CSP.
If the shared Traefik CSP later becomes compatible, remove the `csp = null`
exception and `IMMICH_HELMET_FILE` together so two policies are not emitted.

______________________________________________________________________

## Drift checklist

After restoring Pocket ID, recreating the OIDC client, or upgrading either
service, verify:

- the client ID matches `oauthClientId` in `vms/immich.nix`
- all three callback URLs are exact
- the configured scopes remain exactly `openid email profile`
- only the reviewed Immich group is allowed
- Pocket ID signup does not assign the Immich group by default
- the SOPS secret matches the active Pocket ID client
- `autoRegister` and `autoLaunch` remain enabled
- password login remains disabled
- no manually pre-created or restored Immich account is left unlinked
- a newly approved non-admin user can register through Pocket ID
- no non-loopback plain-HTTP callback is registered in Pocket ID
- exactly one CSP response header is present

______________________________________________________________________

## Upstream references

- [Immich OAuth](https://docs.immich.app/administration/oauth/)
- [Pocket ID Immich client](https://pocket-id.org/docs/client-examples/immich)
- [Pocket ID allowed groups](https://pocket-id.org/docs/configuration/allowed-groups)
- [Pocket ID environment variables](https://pocket-id.org/docs/configuration/environment-variables)
