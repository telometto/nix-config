# Pocket ID migration plan

This is the resumable implementation handoff for moving supported interactive
services to Pocket ID. The supporting evidence and compatibility snapshot is
in [Pocket ID support across the configured services](pocket-id-service-support.md).

This document does not authorize an authentication, secret, network-policy, or
deployment change. Each cutover remains a separate, observable change.

## Resume here

| Field | Value |
| --- | --- |
| Repository anchor | `3d0b6b60804093c3faac5cb232abbd29b5b53a31` |
| Research snapshot | 2026-08-02 |
| Support-report SHA-256 | `734a1c7b44c0b0fc299ff55ce74e453e4ce2fc05d2d90c1025377aa8555b0d8f` |
| Overall status | Planning decisions complete; documentation refreshed; implementation not started |
| Last verified | 2026-08-02, repository, pinned-source, and support-report review only |
| Next action | Refresh both anchors, then revalidate the deployed Immich reference implementation |

Before implementation:

1. Compare the current revision with the repository anchor and review every
   intervening authentication, service, publication, secrets, and network
   policy change.
1. Refresh [the support report](pocket-id-service-support.md) against the
   currently pinned service versions and upstream primary documentation.
1. Recompute its digest with
   `sha256sum docs/pocket-id-service-support.md`, replace the digest above, and
   record the new repository revision.
1. Update the affected service's **Last verified** and **Next action** fields.
1. Stop if the refreshed evidence contradicts this plan; resolve the design
   before changing authentication.

## Completion gates

Pocket ID migration is complete for a service when Pocket ID is its normal
interactive login and all five gates below are satisfied. Removing every local
password path is not a universal completion gate. It is an optional,
service-specific hardening state that requires a later recommendation,
explicit approval, and separate deployment.

- **Configuration ready:** The service-local configuration and runtime-only
  secret path build without putting a secret in this repository or the Nix
  store.
- **Client registered:** A dedicated Pocket ID client has exact callbacks,
  `requiresReauthentication = true`, and only its reviewed admission group.
- **Identity ready:** Existing accounts were linked through an authenticated,
  application-controlled flow, or an explicitly documented exception was
  completed without email-based account adoption.
- **OIDC validated:** Admission, local roles, browser and native-client
  workflows, deprovisioning, and relevant non-browser integrations were tested.
- **Recovery and rollback verified:** Pocket ID recovery, service-local
  recovery, backups, and the declarative rollback were exercised rather than
  merely documented.

`Operator confirmed` records a live-use statement, not completion of every
negative, recovery, or rollback test. `Historical record` means an existing
operation document reports prior success; revalidate it before treating it as
current evidence. A disabled service can advance only to **Configuration
ready**. No Pocket ID client, group, or secret is created until activation is
explicitly approved.

| Service | Configuration ready | Client registered | Identity ready | OIDC validated | Recovery/rollback verified | Optional password hardening | Last verified | Next action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Immich | Declared | Existing | Historical record | Operator confirmed | Not verified | Already declared; revalidate | 2026-08-02 operator confirmation and documentation review | Recheck admission, recovery, rollback, web, and mobile behavior |
| Grafana on Blizzard | Not started | Not started | Not started | Not started | Not started | Requires later approval | 2026-08-02 plan | Add the service-local OIDC interface |
| Grafana on Snowfall | Not started | Not started | Not started | Not started | Not started | Requires later approval | 2026-08-02 plan | Reuse the interface with an independent client |
| Gitea | Not started | Not started | Not started | Not started | Not started | Requires later approval | 2026-08-02 plan | Prepare coexistence deployment |
| Matrix/MAS | Not started | Not started | Not started | Not started | Not started | Requires later approval | 2026-08-02 plan | Add one stable upstream-provider ULID and runtime secret |
| Grafana on Avalanche | Not started | Deferred | Deferred | Deferred | Deferred | Deferred | 2026-08-02 plan | Make configuration ready; verify a stable browser URL before activation |
| Actual Budget (disabled) | Not started | Deferred | Deferred | Deferred | Deferred | Deferred | 2026-08-02 plan | Add configuration-only OIDC wiring |
| Paperless-ngx (disabled) | Not started | Deferred | Deferred | Deferred | Deferred | Deferred | 2026-08-02 plan | Add configuration-only provider wiring |
| Mealie (disabled) | Not started | Blocked | Blocked | Blocked | Blocked | Blocked | 2026-08-02 plan | Add configuration-only wiring; do not activate without a safe identity binding |

## Invariants

- Create one Pocket ID client per activated service and one per activated
  Grafana instance. Never share a client secret or callback set across relying
  applications.
- Name admission groups `oidc-<service>`. Treat each Grafana instance as a
  service, for example `oidc-grafana-blizzard`. Pocket ID groups control
  admission only; roles and privileges remain application-local. Do not create
  `oidc-<service>-admin` groups for this migration.
- Request `openid email profile`. Request `groups` only if a later documented
  service requirement is reviewed and approved.
- Set `requiresReauthentication = true` on every Pocket ID service client. An
  emailed Pocket ID one-time code may recover the Pocket ID account, but it
  cannot by itself authorize a relying service; the user must authenticate with
  a passkey. Existing relying-service sessions are unaffected.
- Store every client secret in the private `nix-secrets` flake. Only public
  client IDs and runtime secret paths may enter this repository. Do not place
  secret values in Nix strings, generated store files, command lines, or Git.
- Pocket ID clients and groups are runtime objects administered manually in
  Pocket ID and protected by Pocket ID database backup and restore. Nix owns
  consuming-service configuration and secret interfaces. Do not add an API
  reconciler.
- Never auto-link an existing application account by matching email. Use an
  authenticated application-controlled link and fail on conflicts. Grafana's
  documented new-identity procedure is an explicit exception; Mealie remains
  blocked rather than weakening this rule.
- Removing a user from a Pocket ID admission group prevents new
  authorizations; it does not terminate existing application sessions.
  Deprovision in two steps: remove the group, then revoke service sessions and
  disable or remove the application account. Verify both a fresh login and the
  existing session are denied.
- Keep API tokens, service-account tokens, Git credentials, Matrix sessions,
  budget-file passwords, and other protocol credentials separate from browser
  login.
- Use a provisioned local recovery credential plus a tested declarative
  re-enable path by default. Keep a continuously enabled break-glass login only
  when it is tightly network-restricted and monitored.
- Configuration-ready work for disabled services includes module wiring,
  secret declarations and interfaces, callbacks, and safe coexistence
  defaults. It excludes runtime clients, groups, secrets, and gates while the
  service remains disabled.
- Use an existing service settings interface when it safely handles secrets.
  Add a service-local interface only for secure secret rendering or the
  repeated Grafana configuration. Do not add a global Pocket ID abstraction.

## Pocket ID prerequisites and user workflow

Repository configuration can proceed before these prerequisites. Creating an
active client or cutting over a service cannot.

- Disable open signup with `ALLOW_USER_SIGNUPS`; the administrator creates each
  user with a mandatory email and username, assigns admission groups, and
  manually triggers the initial one-time-access email.
- Email verification is encouraged but is not an access gate. Pocket ID can
  emit `email_verified = false`, and the order of email verification and
  passkey registration is not enforced. Test each relying service with that
  claim rather than promising a verification gate.
- One user passkey is sufficient. A user who loses it may request an emailed
  Pocket ID one-time-access code and register a replacement without operator
  intervention. The user's mailbox is therefore a deliberate recovery
  authority, and protecting it is the user's responsibility.
- Keep Pocket ID's default session and reauthentication timing unchanged. The
  client-level `requiresReauthentication` setting above requires a passkey for
  service authorization without forcing a login every time a site is opened.
- SMTP is a dependency for every active client and cutover. Before proceeding,
  send real initial-access and recovery emails and follow their links. Alert on
  Pocket ID mail-send failures. Do not maintain a synthetic test user solely
  for continuous email testing; existing passkey logins must continue through
  an SMTP outage.
- Before the first new active client, register two independent administrator
  passkeys, exercise root or CLI one-time-access recovery, take a fresh VM
  snapshot and logical export outside the VM, and rehearse a restore. After the
  restore, verify health, discovery, administrator login, and one relying
  application.

## Rollout protocol

Use this active-service order:

1. Revalidate Immich.
1. Pass the global Pocket ID recovery and SMTP gates.
1. Enable Grafana on Blizzard.
1. Enable Grafana on Snowfall.
1. Enable Gitea.
1. Enable Matrix/MAS last.

Avalanche remains configuration-ready and deferred until it has a stable
browser URL. Configuration-only work for disabled services is independent of
this runtime order.

For each activated service:

1. Prepare and build the consuming-service configuration and secret interface.
1. Create the `nix-secrets` value, dedicated Pocket ID client, exact callbacks,
   and admission group only when activation is approved.
1. Deploy OIDC with the existing recovery login available.
1. Complete the service's identity procedure, restart once, and test normal
   browser, native-client, recovery, negative-access, and integration paths.
1. Observe at least seven consecutive clean days with no unexplained service
   or identity-provider errors. Restart the clock after any material
   authentication change.
1. Exercise rollback and update this document's gate, **Last verified**, and
   **Next action** fields.
1. If password removal is recommended after the evidence is reviewed, obtain
   explicit approval and deploy it as a separate hardening change.

Deploy one service at a time. A successful build does not satisfy any runtime
gate.

## Native OIDC work packages

### Immich — operational reference implementation

**Status:** OIDC operational; operator confirmed 2026-08-02; full gate
revalidation due\
**Last verified:** 2026-08-02 operator confirmation plus documentation and
configuration review\
**Next action:** Recheck the deployed client, web and mobile workflows,
admission boundary, recovery path, and rollback; change nothing unless drift is
found

Preparation:

- [x] Keep the checked-in OAuth configuration and runtime SOPS secret path in
  [`vms/immich.nix`](../vms/immich.nix).
- [ ] Verify the client is restricted to `oidc-immich` and that signup grants
  no eligibility group by default.
- [ ] Satisfy the global Pocket ID recovery and SMTP gates before using Immich
  as evidence for another cutover.
- [ ] Recheck `autoRegister = true` as provisioning only after Pocket ID group
  authorization; do not pre-create unlinked Immich users.

Coexistence:

- [x] Existing users were linked before password login was disabled, as
  recorded in [Immich OAuth Operations](immich.md).
- [ ] If drift is found, temporarily enable password login and disable OAuth
  auto-launch only for the controlled linking window.

Cutover:

- [x] The repository declares OAuth auto-launch and disables password login.
- [ ] Confirm the deployed state matches the declaration after a restart.

Negative access:

- [ ] Confirm a Pocket ID user outside `oidc-immich` is denied.
- [ ] Confirm local password login remains rejected.
- [ ] Remove a test user from the group, revoke its Immich sessions or disable
  the account, and confirm access is gone.

Recovery:

- [ ] Exercise Pocket ID administrator recovery and user email recovery,
  confirming `requiresReauthentication` still requires a passkey before a new
  Immich authorization.
- [ ] Verify the declarative recovery path: enable password login, disable
  auto-launch, deploy, and reach the local login URL.

Rollback:

- [ ] Restore the last known-good coexistence settings without rolling a client
  secret back independently of Pocket ID state.
- [ ] Re-enable the passwordless settings and confirm web and mobile login.

### Gitea

**Status:** Not started\
**Last verified:** 2026-08-02 plan against Gitea 1.27.1\
**Next action:** Prepare coexistence configuration; register the `PocketID`
source only after the global gates and both Grafana instances

Preparation:

- [ ] Create client `Gitea`, eligibility group `oidc-gitea`, and exact callback
  `https://git.<public-domain>/user/oauth2/PocketID/callback`.
- [ ] Store the client secret in `nix-secrets`; never check it into this repo or
  render it into the Nix store.
- [ ] Register a Gitea OAuth2 authentication source named exactly `PocketID`
  using OpenID Connect discovery and scopes `openid email profile`, with
  `ENABLE_AUTO_REGISTRATION = true`, `ACCOUNT_LINKING = login`, and
  `REQUIRE_EXTERNAL_REGISTRATION_PASSWORD = false`.
- [ ] Back up Gitea application state before registering the source. Treat the
  source as backed-up application state; do not add a database reconciler.
- [ ] Inventory current administrator identity, PATs, API consumers, and
  Git-over-HTTP remotes.

Coexistence:

- [ ] Leave the password form and password-based Basic authentication enabled.
- [ ] While logged in to the existing administrator account, initiate Gitea's
  authenticated account-linking flow and confirm the same repositories,
  organizations, and administrator privilege are retained. Fail rather than
  adopting an account by matching email.
- [ ] Restart Gitea and observe normal browser and Git use.
- [ ] Test PAT/API access and Git-over-HTTP separately; this repository has
  Gitea SSH disabled.

Optional password hardening:

- [ ] After separate review and approval, deploy
  `ENABLE_PASSWORD_SIGNIN_FORM = false`, password
  `ENABLE_BASIC_AUTHENTICATION = false`, and Gitea-local
  `ENABLE_PASSKEY_AUTHENTICATION = false` through the existing settings
  interface. Pocket ID is the passkey authority; PATs remain enabled.
- [ ] Confirm Pocket ID logout/relogin in a private browser.

Negative access:

- [ ] Confirm a Pocket ID user outside `oidc-gitea` cannot sign in.
- [ ] If optional hardening is later deployed, confirm the password form and
  password-based Basic authentication are rejected while PAT-based Git and API
  operations still work.
- [ ] Revoke sessions or disable the Gitea account when group access is
  removed.

Recovery:

- [ ] Verify a backed-up Gitea authentication source and database can be
  restored.
- [ ] Provision a local administrator recovery credential and exercise the
  declarative path that re-enables local login.

Rollback:

- [ ] Re-enable both password settings and deploy.
- [ ] Confirm local administrator login, then repeat the seven-day observation
  period before considering the optional hardening state again.

References: [Pocket ID Gitea guide](https://pocket-id.org/docs/client-examples/gitea)
and [Gitea configuration settings](https://docs.gitea.com/next/administration/config-cheat-sheet).

### Grafana — Blizzard, Snowfall, and deferred Avalanche

**Status:** Not started\
**Last verified:** 2026-08-02 plan against Grafana 13.0.3\
**Next action:** Implement `sys.services.grafana.oidc`, then deploy one instance
at a time

Preparation:

- [ ] Add a service-local `sys.services.grafana.oidc` interface that renders
  Generic OAuth settings, accepts a runtime `clientSecretFile`, and never
  copies the secret into the store.
- [ ] Keep issuer/endpoints, client ID, scopes, and hardening switches local to
  the Grafana module; do not add a global Pocket ID abstraction.
- [ ] Create separate clients, secrets, callbacks, and groups when each instance
  is activated: `oidc-grafana-blizzard` for `metrics` and
  `oidc-grafana-snowfall` for `metrics2`.
- [ ] Register each callback as
  `https://<instance-hostname>/login/generic_oauth`; do not invent a public
  Avalanche callback until its actual browser URL is confirmed.
- [ ] Request `openid email profile`, keep role synchronization disabled, keep
  `oauth_allow_insecure_email_lookup = false`, and manage Grafana roles
  locally.
- [ ] Inventory local users, organizations, roles, alert automation, and API
  consumers. Keep automation on service-account tokens.

Coexistence:

- [ ] Deploy Blizzard Generic OAuth with the login form and Basic auth enabled.
- [ ] Do not adopt an existing Grafana user by matching email. Sign in through
  Pocket ID to create a new Grafana identity, then promote it locally to the
  required administrator role.
- [ ] Retain the existing local administrator as the recovery identity.
- [ ] Do not migrate preferences or other per-user state unless the inventory
  finds material data that warrants a separately reviewed procedure.
- [ ] Restart and observe normal dashboards, alerts, and automation.
- [ ] Repeat independently on Snowfall. Keep Avalanche configuration-ready;
  create no client until its stable browser URL and activation are approved.

Optional password hardening:

- [ ] After each instance passes its own observation period and receives
  separate approval, set `disable_login_form = true` and
  `[auth.basic] enabled = false` in a distinct deployment.
- [ ] Revalidate the administrator and a normal user in private browsers.

Negative access:

- [ ] For each instance, deny a Pocket ID user outside its eligibility group.
- [ ] Confirm the new Pocket-backed identity has its locally assigned role and
  an ordinary user cannot gain elevated privilege through claims.
- [ ] If optional hardening is later deployed, confirm Basic auth fails while
  service-account-token automation works.

Recovery:

- [ ] Provision and test the retained local administrator recovery credential;
  restrict and monitor a continuously enabled path if one is required.
- [ ] Verify dashboards, datasources, alerts, and user roles survive an OIDC
  disable/re-enable cycle.

Rollback:

- [ ] Re-enable the login form and Basic auth on only the affected instance.
- [ ] Confirm recovery login, correct the client/configuration, then repeat the
  observation period before reconsidering optional hardening.

Reference: [Grafana Generic OAuth](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/generic-oauth/).

### Matrix and Matrix Authentication Service

**Status:** Not started\
**Last verified:** 2026-08-02 plan against MAS 1.21.0\
**Next action:** Add one stable Pocket ID upstream provider while MAS passwords
remain enabled

Preparation:

- [ ] Generate one stable provider ULID, commit the non-secret ULID, and use it
  in `https://matrix.<public-domain>/upstream/callback/<provider-ULID>`.
- [ ] Create client `Matrix`, group `oidc-matrix`, and the exact callback.
- [ ] Store the client secret in `nix-secrets` and expose it to MAS only through
  `client_secret_file` in the runtime configuration.
- [ ] Add Pocket ID under `upstream_oauth2.providers` with
  `on_conflict = "fail"`; do not enable automatic conflict linking.
- [ ] Import and require Pocket ID email. Record that pinned MAS treats a
  trusted upstream email as authenticated even when Pocket ID emits
  `email_verified = false`; this is an identity-provider trust decision, not a
  Pocket ID email-verification gate.
- [ ] Define new Matrix localparts as the lowercased Pocket ID username. Require
  a Matrix-safe username before assigning `oidc-matrix`, retain the confirmation
  step, and never derive the localpart from email. A later Pocket ID username
  change does not rename the Matrix ID.
- [ ] Back up MAS, Synapse, Pocket ID, encryption keys, and signing keys.

Coexistence:

- [ ] Immediately set `account.password_registration_enabled = false` so new
  local password accounts cannot be created. Keep `passwords.enabled = true`
  and password change enabled during the linking phase.
- [ ] Require each existing user to sign in with their MAS password and initiate
  the Pocket ID link from authenticated MAS account management.
- [ ] Test Element Web, Element X, legacy login compatibility, token refresh,
  logout, device verification, and a second-device login.
- [ ] Restart MAS/Synapse and complete a normal-use observation period.

Optional password hardening:

- [ ] Inventory every enabled human account. Each must be linked or explicitly
  locked/deactivated; bots and token-only identities are tracked separately.
- [ ] Only after the inventory reaches zero unlinked enabled human accounts and
  separate approval is given, disable MAS passwords and password change in a
  distinct deployment.
- [ ] Repeat web, native-client, refresh, logout, and device-verification tests.

Negative access:

- [ ] Confirm a Pocket ID user outside `oidc-matrix` cannot link or sign in.
- [ ] Confirm conflicting identities fail rather than auto-linking.
- [ ] Revoke Matrix sessions or disable the MAS account during deprovisioning;
  group removal alone is insufficient.
- [ ] Keep Pocket ID backchannel logout inactive because the integration does
  not support it; use the manual two-step deprovisioning procedure.

Recovery:

- [ ] Exercise MAS administrator and Pocket ID passkey recovery while passwords
  remain enabled.
- [ ] Verify existing Matrix access/refresh tokens behave as expected through
  an IdP interruption and document the intended revocation response.

Rollback:

- [ ] Re-enable MAS passwords and password change without removing the stable
  provider ULID; keep new password registration disabled.
- [ ] Confirm a recovery login, repair OIDC, and repeat the full client matrix
  and observation period before reconsidering password hardening.

Reference: [MAS upstream SSO](https://element-hq.github.io/matrix-authentication-service/setup/sso.html).

### Actual Budget — disabled

**Status:** Disabled; configuration not ready\
**Last verified:** 2026-08-02 plan against Actual Budget 26.7.0\
**Next action:** Add a narrow configuration-only OIDC interface; create no
runtime Pocket ID objects

Preparation:

- [ ] Extend `sys.services.actual` with only the discovery URL, callback,
  client ID, runtime client-secret path, and enforcement/login-method controls
  needed by the NixOS module's `_secret` support.
- [ ] Record callback `https://actual.<public-domain>/openid/callback`, intended
  client `Actual`, and intended group `oidc-actual`, but do not create the
  client, group, or secret while the VM is disabled.
- [ ] Keep budget-file encryption and any budget password as a separate data
  boundary.
- [ ] Mark only **Configuration ready** while the VM remains disabled.

Coexistence:

- [ ] On deliberate activation, initially put only the operator in
  `oidc-actual`. The first OIDC user becomes the immutable server owner in the
  UI, so the operator must sign in first and verify ownership before any other
  users are added.
- [ ] After the owner gate, allow group-gated automatic user creation. Keep
  budget and role access application-local.

Optional password hardening:

- [ ] Separately enforce OpenID-only server login.
- [ ] Confirm budget-file encryption still prompts and behaves independently.

Negative access:

- [ ] Deny a Pocket ID user outside `oidc-actual`.
- [ ] Confirm removing the owner from the group plus revoking/disabling the
  Actual account terminates access.

Recovery:

- [ ] Verify server-login recovery without weakening budget-file encryption.
- [ ] Restore and open a backed-up budget through the intended recovery path.

Rollback:

- [ ] Turn OpenID enforcement off and restore coexistence login.
- [ ] Confirm the owner can recover, then repeat validation before enforcing
  OpenID-only login in a separately approved hardening deployment.

Reference: [Actual OpenID](https://actualbudget.org/docs/config/oauth-auth/).

### Paperless-ngx — disabled

**Status:** Disabled; configuration not ready\
**Last verified:** 2026-08-02 plan against Paperless-ngx 2.20.15\
**Next action:** Add configuration-only django-allauth OIDC wiring through a
SOPS environment-file interface

Preparation:

- [ ] Record callback
  `https://docs.<public-domain>/accounts/oidc/pocket-id/login/callback/`, intended
  client `Paperless`, and intended group `oidc-paperless`; create no runtime
  object or secret while the VM is disabled.
- [ ] Add an interface for a runtime SOPS environment file containing the
  django-allauth provider JSON; never put its client secret in Nix settings or
  the store, and create no secret value while the VM is disabled.
- [ ] Arrange for the runtime environment file to reach every Paperless process
  that needs the provider configuration when the service is enabled, without a
  dangling secret reference while it is disabled.
- [ ] Leave SSO redirection and regular-login disabling off while the VM is
  disabled; mark only **Configuration ready**.

Coexistence:

- [ ] On activation, link the existing superuser from Paperless's authenticated
  Profile flow while normal frontend login remains available. Do not adopt an
  account by unauthenticated email matching.
- [ ] Use Pocket ID only for admission; keep Paperless permissions and
  superuser status application-local with no group-to-role synchronization.
- [ ] Restart all relevant Paperless processes and observe document ingestion,
  web use, API clients, and background jobs.

Optional password hardening:

- [ ] Separately enable SSO redirection and
  `PAPERLESS_DISABLE_REGULAR_LOGIN=true`.
- [ ] Block public `/admin/` and password-based API-token issuance. Keep one
  strong local superuser credential in SOPS and expose `/admin/` only through a
  trusted recovery route.
- [ ] Prove there is no direct VM or LAN path that bypasses the public frontend
  policy before describing Paperless as passwordless.

Negative access:

- [ ] Deny a Pocket ID user outside `oidc-paperless`.
- [ ] Confirm the linked superuser keeps superuser privilege and an ordinary
  user cannot acquire it.
- [ ] Verify Django admin and API local credentials remain separate from the
  frontend login policy.

Recovery:

- [ ] Test the trusted `/admin/` route and SOPS-managed local superuser.
- [ ] Verify API and ingestion recovery without exposing the recovery path
  publicly.

Rollback:

- [ ] Disable SSO redirection and restore regular frontend login.
- [ ] Confirm superuser recovery, repair OIDC, and repeat the observation period
  before reconsidering optional hardening.

Reference: [Paperless configuration](https://github.com/paperless-ngx/paperless-ngx/blob/dev/docs/configuration.md).

### Mealie — disabled

**Status:** Disabled; configuration not ready\
**Last verified:** 2026-08-02 plan against Mealie 3.16.0\
**Next action:** Add configuration-only OIDC wiring; keep activation blocked on
a safe stable-subject identity model

Preparation:

- [ ] Record callback `https://recipes.<public-domain>/login`, intended client
  `Mealie`, and intended admission group `oidc-mealie`; create no runtime
  client, group, or secret while the VM is disabled.
- [ ] Extend the service-local interface for discovery, `openid email profile`,
  callback, client ID, and runtime client-secret path without enabling OIDC.
- [ ] Leave password login enabled and OIDC auto-redirect disabled while the VM
  is disabled; mark only **Configuration ready**.
- [ ] Record the activation stop gate: pinned Mealie 3.16.0 matches OIDC users
  by mutable username or email and does not safely bind an authenticated local
  account to stable `(issuer, sub)`.

Activation gate:

- [ ] Do not activate until one of these is separately reviewed and approved:
  upstream stable-subject binding, a maintained local patch, or an explicit
  Mealie-specific identifier-match exception based on a live account inventory.
- [ ] Keep roles and privileges Mealie-local; do not add an OIDC admin group or
  role mapping.

Optional password hardening after the activation gate:

- [ ] Separately set `ALLOW_PASSWORD_LOGIN=false` and enable OIDC auto-redirect.
- [ ] Confirm administrator logout/relogin in a private browser.

Negative access:

- [ ] Deny a Pocket ID user outside `oidc-mealie`.
- [ ] Confirm a newly admitted user receives only its application-local role
  and cannot gain administrator privilege through claims.
- [ ] Revoke sessions or disable the Mealie account after group removal.

Recovery:

- [ ] Test a local administrator recovery while coexistence is active.
- [ ] Verify credentials-file rotation and service restart ordering.

Rollback:

- [ ] Re-enable password login and disable OIDC auto-redirect.
- [ ] Confirm administrator recovery, then repeat the observation period before
  reconsidering optional hardening.

Reference: [Mealie OIDC](https://docs.mealie.io/documentation/getting-started/authentication/oidc/).

## Deferred gateway strategy

For services without native OIDC, use this path only after a separate gateway
design and approval:

```text
Pocket ID -> OAuth2 Proxy -> Traefik ForwardAuth -> application
```

This applies to SearXNG, Sonarr, Radarr, Prowlarr, Readarr and other enabled Arr
applications, Bazarr, SABnzbd, qBittorrent, Firefox, Glance, Scrutiny, Lingarr,
and the Traefik dashboards.

- Keep backend authentication enabled during rollout.
- Give machine integrations source-restricted routes that still require the
  application's API key or token. A path bypass alone is not authentication.
- Close direct host forwards, LAN exposure, open firewalls, and lateral
  MicroVM bypasses before considering backend-auth removal.
- Blizzard's network policy is currently `enforce`; the separately approved
  audit gate and enforcement decision are recorded in the [deployment
  audit](deployment-audit-2026-08-08-microvm-networking.md), and the finalized
  post-enforce observation and root-counter closure are recorded in the
  [Blizzard MicroVM enforce-mode audit](2026-08-18-blizzard-microvm-enforce-audit.md).
  Treat `audit` only as a temporary declarative rollback mode: investigate every
  event, add only verified peer edges, and never switch automatically from
  audit to enforce.
- Do not remove backend authentication until enforcement and negative
  reachability tests prove every alternate path is closed.
- Treat Firefox last because bypassing its gateway exposes a remotely
  controlled browser. Account for its current direct forwards explicitly.
- Preserve the SABnzbd, qBittorrent, Arr, Bazarr, and Scrutiny machine/API paths
  with both source restrictions and application credentials.

Gateway work is deferred and does not satisfy any native-service gate in this
document or authorize implementation.

## Exclusions

These are recorded without migration checklists:

- Plex, Overseerr, and Tautulli remain a Plex identity island. A Pocket-backed
  front-door check would not replace Plex identities, native clients, or API
  tokens.
- Jellyfin is excluded because its archived third-party SSO plugin and native
  client limitations do not provide a clean long-term Pocket ID migration.
- SSH, Samba, NFS, WireGuard/Tailscale and other VPNs, machine APIs, service
  tokens, and PAM/system login are outside browser OIDC.

## Validation record

Complete these for every native service before checking **OIDC validated**:

- [ ] An authorized intended user can sign in.
- [ ] A Pocket ID user outside the eligibility group is denied.
- [ ] The intended administrator has the documented service-specific identity
  and locally assigned privileges; any exception to existing-account linking
  is recorded.
- [ ] An ordinary eligible user cannot gain administrator privilege.
- [ ] `openid email profile` is sufficient, and no unapproved group-to-role
  mapping is active.
- [ ] A Pocket ID email-recovery login cannot authorize the service until the
  user authenticates with a passkey.
- [ ] Logout and relogin work in a private browser session.
- [ ] Existing API keys, tokens, Git credentials, native clients, and machine
  integrations remain functional.
- [ ] Group removal is paired with session revocation or account disabling and
  denies both fresh login and the previously active service session.
- [ ] The service has restarted at least once with OIDC enabled.
- [ ] At least seven consecutive clean days of normal use completed, including
  all relevant browser and native clients, with the clock restarted after any
  material authentication change.
- [ ] The recovery path and rollback deployment were exercised.
- [ ] Relevant service and identity-provider logs show no unexplained errors.

Complete these only for a separately approved password-hardening deployment:

- [ ] The exact password paths to remove and retained protocol credentials are
  documented.
- [ ] The hardened deployment rejects each removed password path.
- [ ] The provisioned recovery credential or restricted break-glass path works.
- [ ] Rollback was exercised and another seven-day observation period completed
  before hardening was restored.

After every checkpoint, update the master table and the affected work package's
**Last verified** and **Next action**. During future implementation, build each
affected host or MicroVM independently, run `nix flake check`, deploy one
service at a time, and treat live probes—not builds—as runtime evidence.
