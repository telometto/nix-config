# Immich OAuth Operations

Immich uses Pocket ID as an OpenID Connect (OIDC) provider at:

```text
Issuer: https://id.<public-domain>
Application: https://photos.<public-domain>
```

The checked-in configuration deliberately keeps automatic registration and
automatic OAuth launch disabled. Password login remains enabled as a recovery
path. These are safety invariants, not unfinished rollout steps.

______________________________________________________________________

## Why migration is staged

The pinned Immich 2.7.5 release first looks up an OAuth identity by its stable
OIDC `sub`. If no identity is linked, it can match an existing Immich account
by email and link it before applying the `autoRegister` setting. It does not
require the OIDC `email_verified` claim for that match.

Pocket ID does not verify email in this deployment because SMTP is not
configured. To keep an unverified or self-selected email from reaching that
linking branch, the deployment enforces all of the following:

- The Immich client requests `openid profile`, deliberately omitting `email`.
- The Immich OIDC client is restricted to a reviewed Pocket ID group.
- Existing users link OAuth while already authenticated to Immich.
- Immich automatic registration remains disabled.
- Password login remains available for a tested local administrator.

Do not enable automatic registration, automatic launch, or password-only
lockout without a new security review and an upstream identity-linking control
that does not trust an unverified email.

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
Scopes: openid profile
ID token signing algorithm: RS256
Userinfo signing algorithm: none
Token endpoint authentication: client_secret_post
```

The actual scope is `openid profile`; `email` is intentionally absent. Pocket
ID releases email claims only for the email scope, while Immich's authenticated
link endpoint needs only the stable OIDC `sub`.

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

## Link existing users safely

Complete this procedure for every existing Immich user before treating OAuth
as their login method:

1. In Immich administration, inventory the user's current email.
1. In Pocket ID, verify the intended person's identity and group membership.
   Do not use email equality as proof that the accounts belong to the same
   person.
1. Add the Pocket ID user to the restricted Immich group.
1. Have the user sign in to Immich with their existing local credentials.
1. Open **Account Settings**, then **OAuth**, and link the Pocket ID identity
   from that authenticated session.
1. Sign out and confirm that **Login with Pocket ID** returns the same Immich
   account, library, and role.
1. Test the mobile app with the same non-administrator account.

Do not use a direct OAuth login for an unlinked existing account. With the
email scope omitted and automatic registration disabled, it is expected to be
rejected. The authenticated settings flow establishes the stable OIDC `sub`
without relying on email-based account discovery.

### Onboard a new user

Automatic registration stays disabled. For a new user:

1. Have an administrator create and verify the Pocket ID identity.
1. Add it to the restricted Immich group.
1. Create the Immich account with the user's intended local email. Do not use
   email equality as the OAuth linking mechanism.
1. Give the user a one-time local onboarding credential through a trusted
   channel.
1. Have the user sign in locally, link OAuth from account settings, and then
   validate web and mobile OAuth login.

______________________________________________________________________

## Break-glass recovery

Keep the local Immich administrator credential in the approved password
manager and test it after every authentication change.

If Pocket ID is unavailable:

1. Open `https://photos.<public-domain>/auth/login?autoLaunch=0`.
1. Sign in with the local administrator credential.
1. Inspect Immich and Pocket ID health before changing account links.
1. If an extended outage requires it, set `oauth.enabled = false` in
   `vms/immich.nix`, deploy, and restore OAuth only after a non-admin test
   succeeds.

Never disable password login until an independently tested recovery mechanism
exists.

______________________________________________________________________

## Rotate the OAuth client secret

Pocket ID client-secret regeneration can interrupt OAuth logins. Use a short
maintenance window:

1. Confirm the local Immich administrator login works.
1. Regenerate the Immich client secret in Pocket ID.
1. Immediately replace `immich/oauth_client_secret` in `nix-secrets`, update
   the affected SOPS recipients, commit, and refresh the locked private input.
1. Deploy Blizzard. The SOPS restart request and explicit systemd ordering
   restart Immich only after the new secret generation is active.
1. Verify a non-admin web login and a mobile login.
1. Check `journalctl -u immich-server.service` for OIDC or credential errors.

If validation fails, use the local administrator path; do not add the email
scope or weaken the allowed-group control to restore access.

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
- the configured scopes remain exactly `openid profile`
- only the reviewed Immich group is allowed
- the SOPS secret matches the active Pocket ID client
- `autoRegister` and `autoLaunch` remain disabled
- password login and the local administrator credential still work
- exactly one CSP response header is present

______________________________________________________________________

## Upstream references

- [Immich OAuth](https://docs.immich.app/administration/oauth/)
- [Pocket ID Immich client](https://pocket-id.org/docs/client-examples/immich)
- [Pocket ID allowed groups](https://pocket-id.org/docs/configuration/allowed-groups)
- [Pocket ID environment variables](https://pocket-id.org/docs/configuration/environment-variables)
