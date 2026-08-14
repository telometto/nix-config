# Pocket ID support across the configured services

Research snapshot: 2026-08-02, refreshed against the versions and primary
sources pinned by the current flake. No configuration was changed as part of
this review.

The resumable implementation sequence, gates, and rollback checklists are in
the [Pocket ID migration plan](pocket-id-migration-plan.md). This report remains
the evidence snapshot; update its digest in the plan whenever this report is
refreshed.

The detailed matrix focuses on interactive services. It covers the Blizzard
application stack plus the other configured Grafana and Traefik browser
surfaces. Non-browser protocols and machine endpoints are summarized
separately because OIDC cannot authenticate them.

## Bottom line

Pocket ID can become the interactive login authority for most of the stack, but
not by one uniform mechanism:

- **Native OIDC:** Immich is operational with Pocket ID. Gitea, Grafana, and
  Matrix Authentication Service (MAS) can integrate directly. The currently
  disabled Actual and Paperless-ngx services can be made configuration-ready.
  Mealie exposes native OIDC settings, but its pinned identity-matching behavior
  blocks activation under this plan's safe-linking rule.
- **Pocket-backed gateway only:** SearXNG, the Arr applications, Bazarr,
  SABnzbd, qBittorrent, Firefox, Glance, Scrutiny, and Lingarr need a separate
  OIDC-aware authentication service in front of them. Pocket ID itself is only
  an OIDC provider; with Traefik OSS this means something such as OAuth2 Proxy
  plus `ForwardAuth`, or a separately assessed OIDC middleware. See Pocket ID's
  [proxy guide](https://pocket-id.org/docs/guides/proxy-services) and Traefik's
  [ForwardAuth contract](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/forwardauth/).
- **Plex identity remains:** Plex, Overseerr, and Tautulli do not expose generic
  OIDC configuration for Pocket ID. Their supported passwordless path is Plex
  OAuth/federated Plex login, not Pocket ID.
- **Passkeys do not replace machine credentials:** API keys, access tokens,
  Matrix sessions, Plex tokens, Git credentials, WireGuard keys, and other
  non-browser protocol credentials remain necessary.

Migration completion means Pocket ID is the normal interactive login and its
admission, identity, deprovisioning, recovery, and rollback behavior has been
verified. Removing every application password is a separate, optional
hardening decision per service.

The most important deployment constraint is that Blizzard currently has
[`networkPolicy.mode = "enforce"`](../hosts/blizzard/virtualisation/microvms.nix).
The approved audit gate and enforcement decision are recorded in the
[deployment audit](deployment-audit-2026-08-08-microvm-networking.md). `audit`
remains a declarative rollback mode and does not block lateral MicroVM traffic;
it must not be used to justify disabling an application's own authentication.
Host/LAN port forwards are equivalent bypasses and must also be closed or
independently protected.

## Enabled interactive services

The inventory comes from the evaluated host configurations, Blizzard
[MicroVM declarations](../hosts/blizzard/virtualisation/microvms.nix),
[host services](../hosts/blizzard/services), and
[rootless containers](../hosts/blizzard/virtualisation/containers.nix).
Versions shown below are the versions evaluated from the current flake where
recorded.

| Service | Pocket ID support | Passwordless outcome and boundary |
| --- | --- | --- |
| Pocket ID 2.11.0 | Native authority | Disable open signup. The administrator creates users and assigns admission groups. One passkey is sufficient for ordinary users, whose mailbox is the accepted self-service recovery authority. Require two independent administrator passkeys plus exercised root/CLI recovery, off-VM backup, and restore rehearsal before any new active client. SMTP must prove initial-access and recovery delivery. Set every relying client to require reauthentication so an emailed one-time code cannot by itself authorize a service. |
| Immich 2.7.5 | **Native OIDC; operational** | The repo enables OAuth, uses the Pocket ID issuer, and disables password login in [`vms/immich.nix`](../vms/immich.nix). The operator confirmed working Pocket ID use on 2026-08-02. That does not prove every negative, recovery, rollback, web, and mobile check; those remain revalidation tasks. Immich documents callbacks in its [OAuth guide](https://docs.immich.app/administration/oauth/), and Pocket ID has an [Immich-specific guide](https://pocket-id.org/docs/client-examples/immich). |
| Gitea 1.27.1 | **Native OIDC** | Create a Gitea OAuth2 authentication source with provider `OpenID Connect`, discovery URL from Pocket ID, scopes `openid email profile`, and callback `https://git.<domain>/user/oauth2/PocketID/callback`; see the [Pocket ID Gitea guide](https://pocket-id.org/docs/client-examples/gitea). Use `ENABLE_AUTO_REGISTRATION=true`, `ACCOUNT_LINKING=login`, and `REQUIRE_EXTERNAL_REGISTRATION_PASSWORD=false`, and link existing users only from an authenticated Gitea session. Keep roles local. Optional later hardening can hide the password form, disable password-based Basic auth, and disable Gitea's own passkeys; PATs remain. |
| Grafana 13.0.3 | **Native Generic OAuth/OIDC** | Use independent clients for Blizzard and Snowfall with `openid email profile`, role synchronization disabled, local Grafana roles, and `oauth_allow_insecure_email_lookup=false`. Grafana has no acceptable user-authenticated flow for safely attaching the provider to the existing local account, so create a new Pocket-backed identity, promote it locally, and retain the old local administrator for recovery. Avalanche remains configuration-ready and gets no client until it has a stable browser URL. Optional form/Basic-auth removal is a later per-instance hardening decision. See the [Pocket ID Grafana guide](https://pocket-id.org/docs/client-examples/grafana) and [Generic OAuth reference](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/generic-oauth/). |
| Matrix Synapse + MAS 1.21.0 | **Native upstream OIDC through MAS** | Add Pocket ID under `upstream_oauth2.providers` with a stable callback ULID and `on_conflict=fail`. Existing users sign in with their MAS password and initiate linking from account management. Disable new password registration immediately, but retain passwords and password change during linking. New Matrix IDs use a pre-validated, lowercased Pocket ID username, not email; later username changes do not rename them. Pinned MAS treats trusted upstream email as authenticated even when Pocket ID emits `email_verified=false`, so this plan explicitly accepts that trust semantic. Disable passwords only after zero enabled unlinked human accounts remain and a separate hardening change is approved. Matrix sessions remain protocol credentials. |
| Sonarr 4.0.18 | **Gateway only; explicit external-auth mode** | Sonarr has no native OIDC. Its official [v4 FAQ](https://github.com/Servarr/Wiki/blob/master/sonarr/faq-v4.md) documents `AuthenticationMethod=External` specifically for an external authentication proxy. Keep API-key routes available only to trusted peers. Do not use `External` while MicroVM policy is audit-only. |
| Radarr 6.3 | **Gateway only; external-auth capable** | Same Arr pattern. Radarr's [settings documentation](https://wiki.servarr.com/radarr/settings) separates browser authentication from its privileged API key. Put the UI behind Pocket-backed forward auth and retain the API key only on restricted machine paths. Do not remove app auth until direct access is blocked. |
| Prowlarr 2.4 | **Gateway only** | No native OIDC is documented. It shares the modern Arr host/auth model, but its API is central to Sonarr/Radarr/Readarr integrations. Treat Pocket ID as browser-edge auth only and preserve API-key access from explicitly allowed peers; verify this exact build's `External` setting before disabling its own auth. |
| Readarr | **Gateway only; retired upstream** | No native OIDC is documented. Use the same conservative Arr split: Pocket-backed browser route, application API key for peers, and keep local auth until direct paths are enforced. Readarr is retired, so this is also a migration/removal candidate rather than a new SSO investment. |
| Bazarr | **Gateway only** | Bazarr documents only form/basic password authentication in [Settings](https://wiki.bazarr.media/Additional-Configuration/Settings/). Its official [reverse-proxy example](https://wiki.bazarr.media/Additional-Configuration/Reverse-Proxy-Help/) shows an external auth layer while bypassing `/api`; the API remains API-key based. Restrict that bypass to required peers rather than exposing it publicly. |
| SABnzbd | **Gateway only** | The UI supports a local username/password, while integrations use API keys; see [General configuration](https://sabnzbd.org/wiki/configuration/5.0/general) and the [API reference](https://sabnzbd.org/wiki/advanced/api). Forward auth can replace the human-facing password only if the backend and API exception are network-restricted. The current host forward on port `11031` is a bypass. |
| qBittorrent | **Gateway only** | qBittorrent's documented WebUI API uses application authentication rather than generic OIDC; see the upstream [WebUI API](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-%28qBittorrent-5.0%29) and [reverse-proxy guide](https://github.com/qbittorrent/qBittorrent/wiki/NGINX-Reverse-Proxy-for-Web-UI). Pocket forward auth can protect browser entry, but Arr integrations still need qBittorrent's own supported credential. The current host forward on port `11030` bypasses Traefik. |
| SearXNG | **Gateway only; no app accounts** | SearXNG has no user-account/OIDC surface in its upstream [`settings.yml`](https://github.com/searxng/searxng/blob/master/searx/settings.yml). A Pocket-backed gateway can fully protect normal browser use, but search API/browser integrations need an intentionally designed exception or authenticated client flow. |
| Glance | **Gateway only** | Upstream documents local username/password auth, not OIDC, in its [configuration reference](https://github.com/glanceapp/glance/blob/main/docs/configuration.md). A forward-auth gate is sufficient for the UI if Glance is reachable only through Traefik. |
| Scrutiny | **Gateway only; no app auth** | Scrutiny exposes a web UI and API but documents no native authentication in its [upstream project](https://github.com/AnalogJ/scrutiny). It is a good gateway candidate, but this repo currently sets `openFirewall = true` in [`hosts/blizzard/services/system.nix`](../hosts/blizzard/services/system.nix), so Pocket auth would be bypassable until that exposure is removed. Collectors/API calls need a restricted non-browser path. |
| Lingarr | **Gateway only** | Lingarr exposes local auth controls but no OIDC provider configuration in its upstream [settings reference](https://github.com/lingarr-translate/lingarr/blob/main/Settings.MD). A Pocket-backed gateway can protect the UI. Keep Lingarr's own auth until the localhost/container and any LAN paths are proven inaccessible except through Traefik. |
| Firefox browser-in-browser | **Gateway only** | LinuxServer documents only `CUSTOM_USER`/`PASSWORD` HTTP basic auth and explicitly recommends robust reverse-proxy authentication for Internet exposure in the [Firefox image guide](https://docs.linuxserver.io/images/docker-firefox/). The repo currently supplies those secrets and forwards ports `11052` and `11053`. Because this UI controls a full browser and includes privileged container tooling, close both direct forwards before considering Pocket auth a replacement. |
| Traefik dashboards | **Gateway only** | Traefik OSS has no built-in OIDC login. The Blizzard and Snowfall dashboards are currently tailnet-only, so Tailscale reachability is their access boundary. They can use the same Pocket-backed `ForwardAuth` pattern if per-user browser authentication is desired; keep the dashboard API behind the same gate. |
| Overseerr 1.34.0 | **No native Pocket ID; Plex OAuth or local password** | Overseerr can disable local sign-in, but then Plex OAuth is the only sign-in method according to its [upstream settings](https://github.com/sct/overseerr/blob/develop/docs/using-overseerr/settings/README.md). A Pocket gateway would add a front-door check, not replace Overseerr's Plex identity or API key. The pinned project is archived and superseded by Seerr. |
| Tautulli | **No native Pocket ID; Plex OAuth** | Tautulli removed Plex username/password login and supports the Plex.tv account through OAuth, as recorded in its [upstream changelog](https://github.com/Tautulli/Tautulli/blob/master/CHANGELOG.md). Its API/remote clients use separate credentials. Pocket forward auth would be an additional browser gate, not a native login replacement. |
| Plex | **No Pocket ID** | Plex's supported federated sign-in choices are Plex credentials, Google, and Apple, not a configurable OIDC provider; see [Plex federated authentication](https://support.plex.tv/articles/use-federated-authentication-to-sign-in/). Plex clients and server claiming still depend on Plex authentication/tokens. Pocket forward auth in front of the web route does not replace client authentication and can break native clients. |

## Non-browser and machine authentication

These enabled services are outside Pocket ID's OIDC scope:

- OpenSSH is already passwordless in this repo: password and
  keyboard-interactive login are disabled, and users authenticate with SSH
  keys.
- Samba uses SMB `security = user`; Pocket ID cannot replace SMB credentials.
  Removing that password class would require a different protocol or an
  SMB-supported identity system such as Kerberos, not an OIDC proxy.
- NFS relies on network/client identity and export policy rather than an
  interactive web login. Pocket ID does not change that trust model.
- WireGuard, Tailscale, and RustDesk use their own keys, control-plane
  identities, or tokens. Pocket ID cannot be inserted into those native
  protocols merely by protecting a web page.
- Prometheus, VictoriaMetrics, exporters, Immich machine learning, Ollama,
  LibreTranslate, Subgen, and similar internal endpoints are machine APIs.
  Keep them unexposed or give them protocol-appropriate authentication; do not
  treat a browser-only OIDC gate as machine authentication.

If “no passwords” also includes NixOS console login, desktop unlock, and
`sudo`, that is a separate PAM/system-authentication project. The current repo
still deliberately provisions human password hashes and requires a password
for `sudo`; Pocket ID service integration does not alter those controls.

## Configured but disabled candidates

| Service and evaluated version | Pocket ID support | Caveat |
| --- | --- | --- |
| Actual Budget 26.7.0 | **Native OIDC; configuration-ready while disabled** | Record the documented callback and add the module/secret interface, but create no Pocket ID runtime objects. On activation, initially admit only the operator: the first OIDC user becomes the server owner and that ownership cannot be reassigned in the UI. Verify the owner before adding users; thereafter the group controls admission while Actual controls access. Budget-file encryption remains independent. See Actual's [OpenID guide](https://actualbudget.org/docs/config/oauth-auth/) and [server configuration](https://actualbudget.org/docs/config/). |
| Paperless-ngx 2.20.15 | **Native OIDC; configuration-ready while disabled** | Configure a runtime django-allauth `openid_connect` provider interface but create no Pocket ID runtime objects. Existing users can safely link from the authenticated Profile flow; Pocket groups control admission and Paperless roles remain local. Optional hardening makes the public frontend Pocket-only, blocks public `/admin/` and password-based API-token issuance, and retains one strong SOPS-managed superuser on a trusted recovery route. Existing API tokens and ingestion credentials remain. Prove no direct VM/LAN bypass first. See [Paperless authentication settings](https://docs.paperless-ngx.com/configuration/). |
| Mealie 3.16.0 | **Native OIDC settings; activation blocked** | Configuration-only wiring is useful, but pinned Mealie matches OIDC users by mutable username or email rather than a stable `(issuer, sub)` binding and offers no safe authenticated linking flow. Activate only after upstream stable-subject support, a separately approved maintained patch, or an explicit Mealie-specific identifier-match exception based on a live inventory. Roles remain Mealie-local. See [Mealie OIDC](https://docs.mealie.io/documentation/getting-started/authentication/oidc/). |
| Jellyfin 10.11.11 | **Third-party plugin only; not a clean passwordless target** | Pocket ID's [Jellyfin guide](https://pocket-id.org/docs/client-examples/jellyfin) says SSO works in the browser only; Android, iOS, TV, and desktop apps must use Quick Connect. The required [SSO plugin](https://github.com/9p4/jellyfin-plugin-sso) calls itself alpha and was archived on 2026-05-12. This is unsuitable as the sole long-term authentication path without accepting that maintenance and client limitation. |

## Recommended architecture and rollout

Use native OIDC whenever the application supports it safely. Pocket ID groups
control admission only; application roles remain local. The default client
scopes are `openid email profile`; add `groups` only for a later documented and
approved requirement. Runtime Pocket ID clients and groups are manually
administered only when a service is activated, while Nix owns the consuming
configuration and secret interface.

For the remaining web UIs, a future separately approved design may run one
declarative auth component that authenticates against Pocket ID and have
Traefik call it through `ForwardAuth`. A typical OAuth2 Proxy client uses
callback `https://<service>/oauth2/callback`, issuer `https://id.<domain>`,
scopes `openid email profile`, secure cookies, and `reverse_proxy=true`; Pocket
ID's [proxy guide](https://pocket-id.org/docs/guides/proxy-services) contains the
baseline. Validate trusted-proxy/header handling against the [OAuth2 Proxy
configuration reference](https://oauth2-proxy.github.io/oauth2-proxy/configuration/overview/)
so a client cannot spoof identity headers. This gateway strategy remains
deferred and is not implementation authorization.

Roll active native services out in this order:

1. Revalidate Immich's live admission, web/mobile login, recovery, and rollback.
1. Prove SMTP initial-access and recovery mail, then pass the global Pocket ID
   recovery gate: two independent administrator passkeys, exercised root/CLI
   recovery, off-VM snapshot and logical export, and a successful restore
   rehearsal.
1. Add Grafana on Blizzard, then Grafana on Snowfall, each with a distinct
   client and at least seven consecutive clean observation days.
1. Add Gitea and complete authenticated account linking.
1. Add Pocket ID as MAS's upstream provider last. Test new and existing
   web/native clients, recovery, logout, token refresh, and the complete linked
   human-account inventory.

Avalanche and the disabled services may become configuration-ready in parallel,
but they receive no runtime Pocket ID client, group, secret, or cutover until
activation is explicitly approved. Gateway work remains a later project:

1. Deploy the gateway for low-complexity browser UIs first: Glance, SearXNG,
   Scrutiny, and Lingarr. Keep backend auth where it exists during this phase.
1. Design explicit browser/API routing for each Arr app, Bazarr, SABnzbd, and
   qBittorrent. API exceptions must be source-restricted and continue using
   app API keys or tokens.
1. Complete and approve the existing MicroVM network-policy audit-to-enforce
   process, remove direct host/LAN forwards, and verify negative reachability
   tests. Only then consider disabling built-in auth on proxy-only services.
1. Treat Firefox last because a gateway bypass exposes a remotely controlled
   browser. Accept Plex/Overseerr/Tautulli as a separate Plex identity island,
   or replace those applications with software whose native clients and server
   both support the desired identity model.

Replacing passwords with passkeys is achievable for normal interactive browser
login to the native-OIDC set and, after network enforcement, most web-only
services. This does not make password removal a migration-completion gate, and
it cannot mean that all credentials become passkeys: service-to-service and
native-client protocols still need narrowly scoped, rotatable tokens or keys.
