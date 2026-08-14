# Security roadmap implementation order

This document defines the implementation and pull-request order for the
MicroVM network hardening, Matrix hardening, service-mail, backup, and Pocket ID
OIDC work. It is an execution index for the more detailed plans; it does not
replace their acceptance gates or authorize a deployment, provider change,
secret change, or merge.

## Resume here

| Field | Value |
|---|---|
| Current implementation branch | `main` (PRs #6499, #6577, #6581, and #6582 are merged) |
| Current runtime priority | Run the merged Matrix baseline's live acceptance matrix and seven-day observation gate; deployment and activation still require their explicit gates |
| Next runtime branch | Create a separate branch from current `main` only for an approved Matrix follow-up or the reusable offsite-backup work after the baseline gate |
| Open-PR snapshot | 2026-08-13, live GitHub metadata |
| Planning status | Matrix baseline source implementation is merged; live acceptance, observation, backup, and OIDC work remain |

Do not start backup or OIDC implementation before the Matrix baseline's live
acceptance and observation gates pass. Every runtime branch starts from `main`
after its required predecessor has passed its live gate and merged.

## How to use the planning documents

The documents are not one completely linear checklist. Two drive execution and
two supply contracts and compatibility evidence:

| Document | Role |
|---|---|
| [Matrix hardening plan](matrix-hardening-plan.md) | Primary execution plan after the network-policy rollout; complete work packages A and B before starting OIDC |
| [Service mail architecture](service-mail-architecture.md) | Cross-cutting mail and provider contract used by the Matrix baseline, Pocket ID foundation, and any later Paperless activation |
| [Pocket ID migration plan](pocket-id-migration-plan.md) | Primary execution plan after the Matrix baseline and offsite-backup gates pass |
| [Pocket ID service support](pocket-id-service-support.md) | Compatibility and scope reference; refresh it before OIDC implementation rather than treating it as a deployment checklist |

## Runtime implementation sequence

### 1. Preserve the MicroVM network-hardening gate

PR [#6499](https://github.com/telometto/nix-config/pull/6499) is merged. Keep
its live audit, enforcement, and follow-up evidence attached to any later
network-policy change; do not silently broaden the approved exception set.

The Matrix baseline was allowed to proceed only after this prerequisite merge.

### 2. Complete the Matrix baseline gates

The source implementation is merged through PRs
[#6577](https://github.com/telometto/nix-config/pull/6577),
[#6581](https://github.com/telometto/nix-config/pull/6581), and
[#6582](https://github.com/telometto/nix-config/pull/6582). Follow work package A
in the [Matrix hardening plan](matrix-hardening-plan.md#work-package-a-matrix-baseline-hardening).

The merged baseline owns:

- the managed public path and removal of raw TCP publication;
- Nginx, Synapse, and MAS listener and trusted-proxy restrictions;
- public Synapse Admin API denial and route-specific CORS;
- closed MAS password registration with retained existing password login;
- enabled and tested MAS password recovery;
- a Matrix-specific Proton SMTP token, MAS as the sole Matrix sender, and
  removal of Synapse SMTP configuration;
- measured systemd hardening and sandboxing for the MAS service, MAS database
  helper, and both Matrix runtime-secret generator units, with explicit secret
  read/write paths;
- the reusable public blackbox-probe interface, with Matrix as its first and
  only target;
- the shared availability dashboard and sustained Pushover alerts;

Use the [service mail architecture](service-mail-architecture.md) for the
address, token, provider, and credential-lifecycle requirements. It does not
require a central SMTP relay VM: each sending service submits directly to
Proton with a service-specific token.

The PR merges establish source and evaluation evidence, not deployment
acceptance. Pass the complete live acceptance matrix, including runtime secret
rotation and service restart behavior, then observe seven consecutive clean
days. Do not deploy another Matrix runtime change before the observation gate
and explicit approval are complete.

### 3. Implement reusable MicroVM offsite backup

After the Matrix baseline's live acceptance and observation gates, create
`security/microvm-offsite-backup` from the updated `main` branch. Follow work
package B in the
[Matrix hardening plan](matrix-hardening-plan.md#work-package-b-reusable-microvm-offsite-backup).

As currently designed, this is one cohesive PR that:

- extracts the existing Immich Borg and ZFS mechanism into a reusable module;
- proves that the generated Immich job preserves its existing behavior;
- adds Matrix as the second caller with separate repository, SSH key, and
  passphrase;
- adds the Matrix backup and restore runbook;
- completes a full isolated Matrix restore rehearsal.

If implementation reveals that this is too large to review safely, it may be
split into a module-and-Immich PR followed by a Matrix-caller PR. The second PR
must then be based on the merged first PR, and the full restore remains the
completion gate.

### 4. Establish the Pocket ID foundation

After the offsite-backup gate and merge, create
`security/pocket-id-foundation` from the updated `main` branch. Before adding a
new relying service:

1. Refresh both Pocket ID documents, their repository anchors, pinned-version
   evidence, and support-report digest.
1. Revalidate the existing Immich deployment. An operational revalidation does
   not need a PR unless it requires a configuration change.
1. Configure Pocket ID with its own Proton address, SMTP token, and runtime
   SOPS secret.
1. Prove real initial-access and recovery mail delivery.
1. Register two independent administrator passkeys.
1. Exercise root or CLI recovery.
1. Complete the required off-VM snapshot, logical export, restore rehearsal,
   and post-restore identity-provider checks.

Provider-side addresses and tokens are external operations. Secret values
belong in the private `nix-secrets` flake and may require a coordinated private
branch or PR; they never belong in this repository.

### 5. Migrate one OIDC service at a time

Follow the [Pocket ID migration plan](pocket-id-migration-plan.md#rollout-protocol)
in this order:

| Order | Suggested branch | Runtime change |
|---|---|---|
| 1 | No branch unless required | Revalidate Immich |
| 2 | `security/oidc-grafana-blizzard` | Migrate Grafana on Blizzard |
| 3 | `security/oidc-grafana-snowfall` | Migrate Grafana on Snowfall |
| 4 | `security/oidc-gitea` | Migrate Gitea with authenticated account linking |
| 5 | `security/oidc-matrix` | Add Pocket ID as the MAS upstream provider last |

For every activated service:

1. Start from `main` after the preceding service PR has passed its gate and
   merged.
1. Prepare and build the service configuration and runtime secret interface.
1. Create the dedicated Pocket ID client, exact callbacks, admission group,
   and secret only when activation is approved.
1. Deploy with the existing recovery login retained.
1. Test browser, native-client, negative-access, recovery, rollback, and
   relevant machine-integration paths.
1. Observe seven consecutive clean days and restart the clock after a material
   authentication change.
1. Exercise rollback, update the migration record, and merge before starting
   the next service.

Do not collect all service migrations on the existing local
`security/oidc-migration` branch. That branch currently contains documentation
only. Password removal is also not part of these migration PRs; any recommended
password removal requires fresh evidence, explicit approval, and its own
service-specific hardening PR.

## Pull-request snapshot

This is a dated decision aid, not a permanent status board. Refresh GitHub
metadata before acting.

| PR | State on 2026-08-13 | Roadmap decision |
|---|---|---|
| [#6499 — MicroVM network hardening](https://github.com/telometto/nix-config/pull/6499) | Merged | Prerequisite completed; retain the live audit and enforcement evidence for later network changes |
| [#6577 — SMTP secret management](https://github.com/telometto/nix-config/pull/6577) | Merged | Matrix baseline secret contract is in `main`; live mail and recovery gates remain |
| [#6581 — service hardening and secret management](https://github.com/telometto/nix-config/pull/6581) | Merged | MAS, helper, and runtime-secret-generator sandboxing is in `main`; complete compatibility and rotation evidence |
| [#6582 — service availability monitoring](https://github.com/telometto/nix-config/pull/6582) | Merged | Public probe, dashboard, and alert configuration is in `main`; complete the forced-failure notification test |
| [#6498 — MeTube](https://github.com/telometto/nix-config/pull/6498) | Open | Keep its MicroVM and raw-port changes separate from the completed network-policy and Matrix gates; refresh before merging |
| [#6512 — lock update](https://github.com/telometto/nix-config/pull/6512) | Merged | Not a roadmap prerequisite |
| [#5894 — KubeVirt and Cilium](https://github.com/telometto/nix-config/pull/5894) | Open | Do not merge into this roadmap; it changes Blizzard networking and Traefik assumptions and needs a separate rebase and design review |
| [#5493 — zram](https://github.com/telometto/nix-config/pull/5493) | Open | Not a prerequisite; if revived, rebase and review its `vms/base.nix` and VM-registry changes after network hardening |

### MeTube decision point

PR #6498 remains separate because it adds an enabled MicroVM and raw port after
the network-policy and Matrix baselines were merged. Before merging it, rebase
onto current `main`, include the new VM in the host-owned policy review, and
repeat the relevant positive and negative reachability checks. Do not treat its
existing PR checks as evidence for the current baseline or observation gate.

No other currently open PR is a prerequisite for the Matrix baseline gates.

## Pull-request boundaries

The completed Matrix baseline PR series is:

1. `security/microvm-networking-hardening` — PR #6499.
1. `security/matrix-baseline-hardening` — PR #6577.
1. `security/matrix-baseline-hardening-systemd` — PR #6581.
1. `security/matrix-baseline-hardening-blackbox` — PR #6582.

The remaining planned sequence is:

1. `security/microvm-offsite-backup`.
1. `security/pocket-id-foundation`.
1. `security/oidc-grafana-blizzard`.
1. `security/oidc-grafana-snowfall`.
1. `security/oidc-gitea`.
1. `security/oidc-matrix`.
1. Optional later password-removal PRs, one service at a time.

The following remain outside the critical path:

- A Paperless activation gets its own PR with a co-located, split-mode Proton
  Bridge, local-only listeners, default-deny ingestion rules, and manual review.
  There is no shared Bridge or SMTP VM.
- Configuration-ready wiring for disabled services may proceed independently,
  but must not create runtime Pocket ID clients, groups, or secrets.
- Additional blackbox targets may reuse the interface introduced by the Matrix
  baseline, but each later service addition should remain independently
  reviewable.
- The OAuth2 Proxy and Traefik `ForwardAuth` gateway is a later project, not
  part of the native-OIDC rollout.

## Planning-document branch hygiene

The planning files and documentation-index changes are independent of the
runtime PRs and may merge from a documentation branch based on current `main`.
They change no runtime state and must not be used as evidence that the live
Matrix acceptance or observation gates have passed.

Documentation may merge independently because it changes no runtime state.
Runtime implementation must retain the dependency and observation order above.
