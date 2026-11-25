# Independent KubeVirt service groundwork Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans and scoped parallel workers for the independent application foundation and service batches. Execute task-by-task with failing tests before behavior changes.

**Goal:** Publish paired, disabled groundwork PRs for sixteen services and temporary handoffs suitable for one future agent per service.

**Architecture:** Separate shared reserved Flux paths/generators/catalogs from service-owned manifests and host registrations. Service branches all target a common foundation and edit disjoint paths. Runtime remains deliberately gated and VMs halted.

**Tech Stack:** Existing NixOS retained-disk registry, Python stdlib/PyYAML, Kustomize, Flux CEL, pinned KubeVirt/CDI schemas.

**Spec:** ../specs/2026-11-25-kubevirt-service-groundwork-design.md

## Global Constraints

- No merges, history rewriting, activation, live apply, Flux resume, host restarts, production image/data access or secret inspection.
- Keep production VM definitions untouched; exclude Plex-only Tautulli, preserve Seerr's legacy overseerr identity.
- Sixteen new service IDs from the spec; existing Searx PRs remain separate.
- Branch `dev/kubevirt-groundwork` in both repos, then `dev/kubevirt-<id>` per service; all PRs draft, no auto-merge, co-author every commit.
- Host prep false; Flux storage/app suspend=true, prune=false; VM Halted; Retain PVs, independent paths; no guest network egress.
- Handoff artifacts only in an OS temporary directory, with suggested skills, checklist and references instead of repeated specs.
- Isolated worktrees for concurrent writers; no copying .env files or user data. Tool state stays under XDG/cache/codex or mktemp scratch.

## Review Focus

- Published groundwork must never look application-ready or execute unimplemented runtime (Tasks 2, 3).
- Reserved layers must build before any service PR lands, and service deltas must stack without global-file conflicts (Tasks 2, 4).
- Arbitrary state paths, long/colliding serials, unknown retained data and accidental host enablement must fail closed (Tasks 1, 3).
- VPN-dependent guests must not inherit public-web egress or production media/device access (Tasks 2, 3).
- Every eligible service must have two actual code PRs and an owned agent assignment; references/checklists must agree with real heads (Tasks 4, 5).

### Task 1: Shared host catalog, registration contract and CI

Files: `lib/kubevirt-groundwork/catalog.json`, `lib/kubevirt-groundwork/generate.py`, `tests/kubevirt-groundwork.nix`, `tests/kubevirt-groundwork-check.nix`, tests fixtures, `flake.nix`, CI classifier/contracts, `docs/kubevirt-groundwork.md`.

Interfaces: catalog schemaVersion=1, services list with id/legacyVm/namespace/cpu/memoryMiB/port/protocol/stateVolumes/sources/gates. Disk names are root plus catalog state volumes. `generate.py SERVICE --output PATH` emits only the canonical default-false host registration.

- [ ] Write failing safety tests for disabled registration, exact module structure, state paths and per-service inventory.
- [ ] Observe RED, implement catalog/generator/public contract and exact-path CI mappings preserving global Nix evaluation.
- [ ] Run public contracts, classifier suite, formatting and full shared Blizzard closure build. Expected: all pass; no production configuration change from disabled registrations.
- [ ] Co-author commit, push host foundation and create draft PR against dev/kubevirt-base.

### Task 2: Shared application reservations and generator

Files: `clusters/blizzard-actual-pilot/migrations/{catalog.json,scaffold.py,templates/}`, `migration-layers.yaml`, per-service empty kustomizations, root kustomization, `tests/actual-pilot/test_groundwork.py`, existing Searx fleet-count compatibility test, dedicated README.

Interfaces: consumes byte-identical catalog from Task 1; `scaffold.py SERVICE` populates only `migrations/SERVICE`. Common loader validates service identity and boolean runtimeReady before executing the owned runtime script.

- [ ] Add failing loader, reservation, non-readiness, storage, policy and serial tests.
- [ ] Observe RED; implement valid empty slots, suspended layers and canonical scaffold generator; add actual per-service resource generation rather than empty service PRs.
- [ ] Keep Actual/Searx checks passing; run complete public application check and pinned schema/CEL validation.
- [ ] Co-author commit, push application foundation, draft PR against existing dev/kubevirt-searxng.

### Task 3: Validate the paired generated service contract

Interfaces: selected profile generates host disks matching application PV directories. State volumes are fresh; legacy OS persist and external shares remain planning metadata.

- [ ] Render representative simple, multi-disk and UDP/VPN profiles into disposable source fixtures. Expected: actual VM/PV/Service manifests, private policy, blocked runtime, false readiness, correct resources.
- [ ] Negative controls: host enable true/extra system option, public service, guest egress, path alias/production path, unpinned import, serial collision, string runtimeReady. Expected: refusal/test failure.
- [ ] Verify all sixteen service deltas change only owned files and can coexist; do not merge branches.

### Task 4: Publish every service pair

Interfaces: foundations immutable at their recorded commits; batches own disjoint service IDs and temporary worktrees. Produce paired PRs and per-service receipts in the task scratch directory.

- [ ] Allocate batches across isolated worker worktrees. Each worker is not alone and must preserve other edits/refs.
- [ ] For each service, create dev/kubevirt-ID in each repo from its foundation, generate actual manifests/registration and a service planning record, run public contracts, inspect/gate explicit staged paths, co-author commit and push.
- [ ] Open two draft PRs against their groundwork foundation, record URLs, exact heads, remaining gates and validation. No activation or merges.
- [ ] Repeat for all sixteen, retaining existing Searx PRs and excluding Tautulli. Expected: thirty-two new service PRs, none empty.

### Task 5: Review, handoffs and completion

Files: OS temporary handoff index, reusable AGENT-TEMPLATE.md and sixteen assignments; repo docs reference authoritative artifacts.

- [ ] Fresh whole-foundation/service-contract review; reproduce important defects, repair with RED/GREEN and publish fixes without rewriting history.
- [ ] Create handoffs referencing source/PRs/provenance, owned paths, authoritative shared contract and service-specific remaining gates. Include suggested skills and the standard completion/live-test checklist.
- [ ] Check every remote branch/PR, draft/no-auto-merge, expected base, nonempty code diff and tests at its exact head; inspect CI. Preserve both canonical umbrella aliases and production definitions.
- [ ] Report all PRs via an indexed artifact, exact validation limits and remaining live-test/state/credential/VPN/GPU gates. Stop before activation.
