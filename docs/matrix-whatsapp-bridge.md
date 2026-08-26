# Matrix–WhatsApp bridge

> Status: shaping and placement decision only. This document does not authorize
> a deployment, a WhatsApp login, or a change to `nix-secrets`.
>
> Last reviewed: 2026-08-26

This document plans the addition of [`mautrix-whatsapp`](https://github.com/mautrix/whatsapp)
to the Matrix deployment. The bridge is a separate Go process that connects
WhatsApp Web to Matrix through the Matrix Application Service API; it is not a
Synapse plugin or a MAS component.

## Placement decision

Run the first deployment inside the existing `matrix-synapse-vm`. A dedicated
VM is not required by the bridge and would add a second workload boundary,
network-policy edge, registration-file handoff, backup target, and service
lifecycle to the initial rollout.

The same-VM placement is appropriate because:

- Synapse, MAS, Nginx, and PostgreSQL already share this guest.
- The bridge can call Synapse through `http://127.0.0.1:8008` and expose its
  appservice listener only on `127.0.0.1`, so no new MicroVM port or lateral
  network exception is needed.
- The generated appservice registration can remain guest-local and be read by
  Synapse without copying tokens between VMs.
- The bridge does not need a public HTTP route for normal WhatsApp message
  bridging. The bridge initiates its external WhatsApp connections.

This does not mean that the bridge should share Synapse's data or database. It
should remain a separately managed systemd service with its own persistent
state, database, secrets, permissions, and backup/restore checklist.

A dedicated VM becomes reasonable later if the bridge is opened to many users,
needs independent resource/restart isolation, or is deliberately treated as a
less-trusted workload. That split would require a new VM registry allocation,
an explicit Matrix-to-bridge network-policy edge, a protected appservice
registration-file delivery path, and a separate backup/restore design. It
would still not require public publication of the bridge port.

## Current repository boundary

The current Matrix workload is already a single, dedicated MicroVM:

| Boundary | Current contract |
| --- | --- |
| Guest | `matrix-synapse-vm`, registry address `10.100.0.60`, 4096 MiB RAM, 4 vCPU |
| Public service | Nginx listens on guest TCP `11060`; Blizzard publishes `matrix.<domain>` through Cloudflare Tunnel and Traefik |
| Internal services | Synapse listens on loopback TCP `8008`; MAS listens on loopback; Nginx is the only guest-network listener |
| Host exposure | No raw host TCP `11060` forward; the guest firewall accepts the Matrix service only from Blizzard's MicroVM gateway |
| Persistent state | Separate images for Synapse, PostgreSQL, and MAS, plus the guest `/persist` volume |

The source of truth for these contracts is [`vms/matrix-synapse.nix`](../vms/matrix-synapse.nix),
the [`matrix-synapse` registry entry](../vms/vm-registry.nix), and the
[Matrix section of the MicroVM reference](../vms/README.md#matrix-network-and-authentication-boundary).

## Integration contract

The implementation should preserve the following boundaries.

### Application Service API

The bridge needs a generated `registration.yaml` file. Synapse must include
that file under `app_service_config_files`, and Synapse must be restarted when
the registration changes. The bridge itself does not read the registration
file at runtime; its own configuration contains the corresponding application
service values.

For the same-VM design, use a loopback contract similar to:

- bridge to homeserver: `http://127.0.0.1:8008`;
- homeserver to bridge: `http://127.0.0.1:29318` (or another unallocated
  loopback port); and
- no Traefik, Cloudflare Tunnel, Nginx, or host port-forward route for the
  bridge listener.

The exact Nix options must be checked against the locked nixpkgs revision before
implementation. Nixpkgs carries a [`services.mautrix-whatsapp` module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/matrix/mautrix-whatsapp.nix),
which should be evaluated before writing a bespoke service wrapper.

### Durable state and database

The bridge's linked-device session, crypto state, registration/configuration,
and database must survive a VM restart. Add a separate guest state boundary for
`/var/lib/mautrix-whatsapp`; do not place it in the Synapse or MAS state image
without an explicit migration and restore plan.

The bridge database must be separate from both the `matrix-synapse` and `mas`
databases. Reusing the existing PostgreSQL service with a distinct
`mautrix-whatsapp` database is the preferred durable setup. SQLite is an
acceptable small single-user trial if its own state image and restore test are
kept, but it must not be mistaken for a shared Synapse database.

The bridge state and its database must be added to the Matrix MicroVM backup
inventory before WhatsApp login. A restore must preserve the linked-device
session or explicitly document the re-login procedure.

### Network and media dependencies

The bridge needs outbound access to the WhatsApp Web service and to the local
Synapse listener. It does not need inbound access from WhatsApp or a public
bridge URL for ordinary message bridging. A public `appservice.public_address`
should therefore remain unset unless a later feature specifically requires it.

`ffmpeg` and LottieConverter are needed for animated sticker conversion; the
exact package closure should be verified when the locked Nixpkgs module is
evaluated. Media should continue to use Synapse's media repository and its
existing size/retention policy rather than creating an untracked host path.

### Secrets and permissions

The implementation must keep application-service tokens, the provisioning
secret, any double-puppeting secret, and PostgreSQL credentials out of the
Nix store and repository. Add them to the existing guest-local SOPS pipeline,
with service-specific ownership and systemd ordering like the current Synapse
and MAS secret generators.

Bridge permissions must be explicit. The initial policy should name the
intended Matrix administrator and user(s), avoid granting broad `admin` or
`user` access to `*`, and decide whether relay mode is enabled. Double
puppeting and end-to-bridge encryption should be configured before the first
login if they are part of the desired user experience; upstream notes that
encryption is difficult to retrofit into existing portal rooms.

### WhatsApp account lifecycle

Login is performed interactively through the bridge bot with `login qr` or a
phone pairing code. The linked phone is part of the service's availability
boundary: upstream warns that linked devices disconnect if the phone is offline
for more than two weeks. The rollout must also acknowledge WhatsApp account-ban
risk and define logout, re-login, and account-recovery procedures before using
an important account.

## Same VM versus dedicated VM

| Concern | Existing `matrix-synapse-vm` | Dedicated bridge VM |
| --- | --- | --- |
| Appservice transport | Loopback; no new network edge | Matrix must reach a guest-network bridge port |
| Public exposure | None required | None required, but internal TLS/WireGuard or a restricted edge is needed if not using the shared bridge network |
| Isolation | Shares the Matrix guest fault and trust boundary | Independent restart, resource, and filesystem boundary |
| Repository work | Add service/state/database wiring to the Matrix guest | Add registry entry, VM output, host enablement, network policy, backup, and registration delivery |
| Failure impact | Bridge restart or resource pressure can affect Matrix; systemd limits are required | Bridge failure is less likely to affect Synapse, but the new network and backup paths add failure modes |
| Initial recommendation | **Use this for the first rollout** | Reconsider for multi-user or deliberately isolated operation |

## Implementation sequence

1. Finish the Matrix baseline acceptance and clean observation gates recorded in
   [`matrix-hardening-plan.md`](matrix-hardening-plan.md). This bridge is a new
   Matrix runtime change, not part of the existing baseline or OIDC work.
2. Evaluate the locked `services.mautrix-whatsapp` module and package. Confirm
   the generated registration path, data directory, service user, database
   behavior, optional media dependencies, and systemd hardening options.
3. Add the bridge to the existing guest with a loopback listener and a
   separate `/var/lib/mautrix-whatsapp` state image. Keep the bridge port out of
   the host registry and public publication configuration.
4. Register the appservice with Synapse, provision only the required SOPS
   values, and create a distinct bridge database if PostgreSQL is selected.
5. Extend the Matrix backup/restore inventory and verify service ordering,
   permissions, listener scope, outbound connectivity, and clean restart before
   logging in.
6. Configure encryption/double puppeting if approved, then perform the
   interactive QR/pairing login and validate portal creation, media, reconnect,
   logout, and re-login behavior.

## Acceptance gates

- The bridge binds only on loopback and has no public Traefik, Cloudflare, Nginx,
  or host-forward route.
- Synapse starts with the registration file, and a registration change has a
  clear restart/rollback procedure.
- The bridge has its own service identity, state image, database, secrets, and
  systemd resource/hardening policy.
- The host/guest MicroVM network policy is unchanged because no new VM or
  lateral peer is introduced.
- Matrix's existing federation, client, MAS, media-retention, and raw-port
  acceptance checks still pass.
- A backup and isolated restore preserve or deliberately re-establish the
  WhatsApp linked-device state.
- The operator has documented phone-offline, WhatsApp logout, account-ban, and
  re-login recovery procedures.

## Upstream references

- [`mautrix/whatsapp`](https://github.com/mautrix/whatsapp) — bridge source and overview
- [Go bridge setup](https://docs.mau.fi/bridges/go/setup.html?bridge=whatsapp) — requirements, appservice generation, and systemd model
- [Initial bridge configuration](https://docs.mau.fi/bridges/general/initial-config.html) — homeserver address, database separation, permissions, encryption, and backfill guidance
- [Registering appservices](https://docs.mau.fi/bridges/general/registering-appservices.html) — Synapse registration contract
- [WhatsApp authentication](https://docs.mau.fi/bridges/go/whatsapp/authentication.html) — QR/pairing, phone availability, logout, and account-risk notes
- [Current mautrix-whatsapp configuration](https://docs.mau.fi/configs/mautrix-whatsapp/latest) — bridge-specific options

## Repository sources reviewed

- [`vms/matrix-synapse.nix`](../vms/matrix-synapse.nix)
- [`modules/services/matrix-synapse.nix`](../modules/services/matrix-synapse.nix)
- [`modules/services/matrix-authentication-service.nix`](../modules/services/matrix-authentication-service.nix)
- [`vms/vm-registry.nix`](../vms/vm-registry.nix)
- [`vms/mkMicrovmConfig.nix`](../vms/mkMicrovmConfig.nix)
- [`hosts/blizzard/virtualisation/microvms.nix`](../hosts/blizzard/virtualisation/microvms.nix)
- [`hosts/blizzard/security/traefik.nix`](../hosts/blizzard/security/traefik.nix)
- [`docs/matrix-hardening-plan.md`](matrix-hardening-plan.md)
