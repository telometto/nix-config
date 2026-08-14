# Project roadmap

> Last reviewed: 2026-08-14

This is the repository's curated portfolio of meaningful initiatives that may
be worth implementing. It is a planning index, not a task tracker, deployment
record, or live GitHub status board.

## How to use this roadmap

- Keep one row per meaningful outcome, architectural decision, or multi-step
  change. Individual bugs, routine maintenance, and detailed checklists belong
  in GitHub issues or the linked planning document.
- Candidate ideas are welcome. Add the desired outcome, area, horizon, status,
  dependencies, next action, a source link, and relevant code paths before
  adding an item.
- Keep GitHub issues as the actionable task tracker. Keep design decisions,
  evidence, acceptance gates, and operational procedures in detailed documents.
- Update this file when an initiative is added, reprioritized, blocked, started,
  completed, or dropped. Update the review date when the roadmap is meaningfully
  reviewed; do not synchronize it automatically with every commit or pull
  request.
- Record dependencies explicitly. An initiative is Blocked when a dependency,
  approval, or evidence gate prevents it from starting or continuing.
- Dates are optional. Add a Review by date only when an external deadline or
  deliberate reconsideration date makes one useful.
- Move completed and dropped initiatives to the archive instead of deleting
  them. Preserve the final state and the reason.
- The table is the primary view. Add a small Mermaid dependency graph only if
  the active dependencies become difficult to understand from the table.

### Status

| Status | Meaning |
| --- | --- |
| Candidate | Worth remembering, but not yet being shaped or committed |
| Shaping | Scope, design, evidence, or trade-offs are being clarified |
| Ready | The outcome and next step are clear; no implementation is underway |
| In progress | Implementation or an approved operational change is underway |
| Blocked | Progress is waiting on a dependency, approval, or evidence gate |
| Done | The intended outcome is accepted and complete |
| Dropped | Deliberately not pursuing the initiative |

### Horizon

| Horizon | Meaning |
| --- | --- |
| Now | Current focus or an active operational follow-up |
| Next | Expected after the current focus or its dependencies |
| Later | Worthwhile, but not yet sequenced |
| Someday | Plausible idea without a commitment |

## Active initiatives

Rows are ordered by horizon. The order within a horizon expresses intended
sequence, not a calendar promise. Initial statuses are conservative planning
values; refresh linked evidence before acting on a runtime or security item.

| ID | Initiative / desired outcome | Area | Horizon | Status | Depends on | Next action | Relevant paths | Planning details |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| R-02 | Restore forensic HTTP detection and client attribution, with durable security-log retention | Observability / Security | Now | Shaping | Off-host retention path | Validate CrowdSec message-only acquisition, the trusted-proxy client-IP contract, persistent retention, and host auditd execution telemetry through the approved workflow; feed the evidence into R-13 rather than creating a second logging initiative | [crowdsec.nix](../hosts/blizzard/security/crowdsec.nix), [traefik.nix](../hosts/blizzard/security/traefik.nix), [blackbox.nix](../hosts/blizzard/monitoring/blackbox.nix) | [Blizzard audit](2026-08-13-blizzard-intrusion-audit.md), [Blizzard handoff](2026-08-14-blizzard-paranoid-nixos-handoff.md) |
| R-03 | Harden the Matrix baseline before adding OIDC | Matrix / Security | Now | In progress | R-01 | Run the live acceptance matrix for the merged baseline, document the evidence, and begin the seven-day clean observation gate | [matrix-synapse.nix](../vms/matrix-synapse.nix), [Matrix services](../modules/services/), [matrix-baseline.nix](../tests/matrix-baseline.nix) | [Matrix hardening plan](matrix-hardening-plan.md), [security sequence](security-roadmap-implementation-order.md) |
| R-07 | Scope host service exposure to intended interfaces and sources, with IPv4/IPv6 parity | Networking / Security | Next | Candidate | Explicit admin-exposure contract | Inventory all-interface listeners, make LAN/Tailscale source scope explicit, and test both allowed and denied paths with IPv4/IPv6 parity; feed the result into R-13's host/VM baseline | [Blizzard host configuration](../hosts/blizzard/), [networking.nix](../hosts/blizzard/networking.nix), [storage services](../hosts/blizzard/storage/) | [Blizzard audit](2026-08-13-blizzard-intrusion-audit.md), [Blizzard handoff](2026-08-14-blizzard-paranoid-nixos-handoff.md) |
| R-12 | Establish Snowfall-controlled, flake-native Blizzard deployment with reviewable provenance | Supply chain / Operations | Next | Shaping | R-09 deployment-record contract | Add a pinned `deploy-rs` input and `deploy.nodes.blizzard` referencing `self.nixosConfigurations.blizzard`; prove deploy checks, health, provenance, rollback, and physical-console recovery on a disposable target before live cutover | [flake.nix](../flake.nix), [Blizzard host](../hosts/blizzard/), [auto-upgrade module](../modules/services/auto-upgrade.nix), [CI workflows](../.github/workflows/) | [Blizzard handoff](2026-08-14-blizzard-paranoid-nixos-handoff.md), [deploy-rs](https://github.com/serokell/deploy-rs) |
| R-13 | Establish a host/VM paranoid baseline with service-specific exceptions and explicit admin exposure | Security / Operations | Next | Candidate | R-02 audit telemetry, R-07 source scope, R-12 controlled deployment | Audit physical-host SSH, Nix daemon permissions, service identities, and systemd sandboxing; apply and test compatible `NoNewPrivileges`, `Protect*`, `Private*`, and `Restrict*` controls with documented exceptions while preserving the MicroVM baseline | [Blizzard host](../hosts/blizzard/), [security modules](../modules/security/), [service modules](../modules/services/), [MicroVM base](../modules/virtualisation/microvm-base.nix), [VM base](../vms/base.nix), [tests](../tests/) | [Blizzard handoff](2026-08-14-blizzard-paranoid-nixos-handoff.md), [Blizzard audit](2026-08-13-blizzard-intrusion-audit.md), [architecture reference](reference-architecture.md) |
| R-04 | Extract reusable MicroVM offsite backup and rehearse a Matrix restore | Backup / Reliability | Later | Blocked | R-03 | After the Matrix gate, extract the proven Immich mechanism and complete an isolated restore rehearsal | [borgbackup.nix](../modules/services/borgbackup.nix), [backup.nix](../hosts/blizzard/services/backup.nix), [VM definitions](../vms/) | [Matrix hardening plan](matrix-hardening-plan.md#work-package-b-reusable-microvm-offsite-backup), [Immich backup operations](immich-backup.md) |
| R-05 | Establish the Pocket ID foundation and prove recovery | Identity / Security | Later | Blocked | R-04 | Refresh pinned evidence, then prove mail delivery, independent administrator passkeys, recovery, export, snapshot, and restore checks | [pocket-id.nix](../vms/pocket-id.nix), [Blizzard MicroVMs](../hosts/blizzard/virtualisation/microvms.nix), [SOPS module](../modules/core/sops.nix) | [Pocket ID migration plan](pocket-id-migration-plan.md), [Pocket ID operations](pocket-id.md) |
| R-06 | Migrate enabled services to Pocket ID OIDC one service at a time | Identity / Services | Later | Blocked | R-05 | Revalidate Immich, then follow the documented order: Grafana Blizzard, Grafana Snowfall, Gitea, and Matrix/MAS last | [VM definitions](../vms/), [Blizzard services](../hosts/blizzard/), [service modules](../modules/services/) | [Pocket ID migration plan](pocket-id-migration-plan.md), [Pocket ID service support](pocket-id-service-support.md) |
| R-08 | Close architecture drift and validation gaps across VM registry, host roles, and CI discovery | Platform / CI | Later | Candidate | — | Resolve the flaresolverr exception and choose validation for registry/output consistency, role exclusivity, and host discovery | [vm-registry.nix](../vms/vm-registry.nix), [validate-vm-registry.nix](../vms/validate-vm-registry.nix), [roles.nix](../modules/core/roles.nix), [CI workflows](../.github/workflows/) | [Architecture risks and improvements](architecture-risks-and-improvements.md) |
| R-09 | Make container and deployment provenance reviewable | Supply chain / Operations | Later | Candidate | Deployment-record contract | Pin mutable image tags and define configuration-revision, flake-lock, deployer, generation, health, rollback, and provenance records; make the result R-12's deployment acceptance contract | [containers](../containers/), [service modules](../modules/services/), [CI workflows](../.github/workflows/) | [Blizzard audit](2026-08-13-blizzard-intrusion-audit.md), [Blizzard handoff](2026-08-14-blizzard-paranoid-nixos-handoff.md) |
| R-14 | Evaluate reprovisioning, persistence inventory, impermanence, tmpfs-root, and global `noexec` as a separate recovery/state design | Recovery / Storage | Later | Candidate | R-12 rollback/provenance, R-13 compatibility evidence | Build a disposable image, inventory persistent paths, rehearse restore/reinstall, and verify Nix/build, storage, MicroVM, and break-glass compatibility before changing Blizzard disks or mounts | [disko wiring](../hosts/snowfall/disko.nix), [provisioning tutorial](tutorial-provision-host.md), [VM base](../vms/base.nix), [Blizzard storage](../hosts/blizzard/storage/), [flake.nix](../flake.nix) | [Blizzard handoff](2026-08-14-blizzard-paranoid-nixos-handoff.md), [impermanence](https://github.com/nix-community/impermanence), [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) |
| R-10 | Decide and, if approved, implement Paperless mail ingestion with a split-mode Proton Bridge boundary | Mail / Services | Someday | Candidate | Service-mail contract | Decide whether to activate the design and confirm its local-only, default-deny threat boundary | [protonmail-bridge.nix](../modules/services/protonmail-bridge.nix), [paperless.nix](../modules/services/paperless.nix), [paperless VM](../vms/paperless.nix) | [Service mail architecture](service-mail-architecture.md), [security sequence](security-roadmap-implementation-order.md) |
| R-11 | Design a separate OAuth2 Proxy and Traefik ForwardAuth gateway project | Edge / Identity | Someday | Candidate | — | Write the threat model and scope separately from the native OIDC migration series | [Traefik host configuration](../hosts/blizzard/security/traefik.nix), [Traefik library](../lib/traefik.nix), [service modules](../modules/services/) | [Security sequence](security-roadmap-implementation-order.md) |

## Archive

| Date | Initiative | Final status | Reason or outcome | Links |
| --- | --- | --- | --- | --- |
| 2026-08-14 | R-01 — Complete and keep auditable the host-owned MicroVM network-policy rollout | Done | The approved audit gate and shortened-window exception were recorded, verified service and WireGuard paths passed, and Blizzard is now running the host-owned policy in `enforce`. The 2026-08-13 live audit classified the enforced lateral traffic and found zero spoof, unknown-tap, gateway-bypass, or routed-bypass events. Future policy changes retain the declarative `audit` rollback and evidence-review gate. | [Deployment audit](deployment-audit-2026-08-08-microvm-networking.md), [Blizzard audit](2026-08-13-blizzard-intrusion-audit.md), [network-policy ADR](adr/0002-enforce-host-owned-microvm-network-policy.md) |
