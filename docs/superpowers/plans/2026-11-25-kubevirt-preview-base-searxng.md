# KubeVirt preview base and SearxNG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare a reusable retained-disk boundary and a private SearxNG preview without changing production workloads.

**Architecture:** Extend the validated Actual host platform with an opt-in preview disk registry. Stage SearxNG in independent suspended Flux layers, using a retained Debian root, guest-local Valkey and a per-boot ConfigMap configuration disk. Deliver separate host-base, service-host and application PRs.

**Tech Stack:** NixOS, Python stdlib, systemd, bundled k3s, Flux 2.10.1, KubeVirt 1.9.1, CDI 1.66.1, Podman, SearxNG, Valkey.

**Spec:** ../specs/2026-11-24-searx-kubevirt-preview-design.md

## Global Constraints

- Keep production MicroVMs running; stop before activation. No host service restart, live apply, merge, reboot or disk cleanup.
- Shared branch `dev/kubevirt-base` targets `dev/kubevirt`; host `dev/kubevirt-searxng` targets the base. Application branch targets homelab-apps main. Preserve #5894 and its `dev-kubevirt` compatibility head.
- Commit with `Co-authored-by: Codex <noreply@openai.com>`, push completed branches and open draft PRs. Existing approval covers autonomous implementation and publication.
- Preview registry entries are disabled by default; storage and application Flux layers are suspended by default. Namespace/VM `searx-preview`, one core, 2 GiB guest memory, private TCP 8080.
- Separate retained root: `/flash/enc/vms/kubevirt-pilot/searx-preview/root`, 20 GiB. No adoption of unknown existing images, symlinks, production keys or existing MicroVM/Actual disks.
- Reuse pinned Debian import with CDI node pulling. Pin the official application image by digest. Generate a new guest-local signing key once; never publish its value.
- Consume desired image/settings on every boot from a read-only ConfigMap ISO. A Git power cycle applies changes on the same root; preserve cached offline startup.
- Preserve rate limiting, image proxy, POST and supported intended engine preferences. Valkey listens only on guest loopback.
- Allow private probes and kubevirt namespace AND virt-api pod selector in one ingress peer. DNS plus public web egress excludes private/tailnet/metadata ranges.
- No backups implementation now. rsync.net is the later destination. Put all generated tool state under XDG locations or temporary scratch directories.

## Review Focus

- Adding a preview to an existing cluster must reject nonempty unregistered directories, even with a healthy cluster DB (Task 1).
- Lost DB, ancestor symlink or tampered ownership record must not authorize reimport or data adoption (Task 1).
- A cached image must start without registry access; a changed desired reference must be read at the next boot and support reversal (Task 2).
- First-boot provisioning and per-boot service dependencies must avoid cycles; key generation must preserve existing local identity without logging it (Task 2).
- Publishing or enabling only one half must not silently start/import a preview; private forwarding must allow only its intended API/probe peers (Tasks 2 and 3).

## Files and interfaces

- `modules/virtualisation/actual-pilot.nix`: `previewVMs.<dns-name>.enable` (false), `disks` (nonempty unique safe names, default root). Derive paths under the fixed pilot prefix. An optional `previewDiskDirs` preflight input is emitted only for enabled entries, keeping the default JSON unchanged.
- `modules/virtualisation/scripts/actual_pilot_preflight.py`: metadata-only first registration and reusable ownership records under the isolated cluster state. No disk contents are opened.
- `tests/actual_pilot/test_preflight.py`, `tests/actual-pilot.nix`: fixture recovery/symlink/registration and public Nix default-off/production-preservation checks.
- homelab-apps `clusters/blizzard-actual-pilot/searx-preview/{storage,app,guest}`: retained storage, VM, private policies, generated cloud-init and public ConfigMap configuration. Guest Python runner validates a digest reference and consumes mounted settings on every start; bootstrap installs signed Debian dependencies.
- homelab-apps `layers.yaml`, `namespaces.yaml`, `tests/actual-pilot/{test_pilot.py,test_searx.py,default.nix}`: independently suspended layers, pinned-schema/CEL validation, real runner tests and startup graph checks. Preserve all Actual behavior.
- `hosts/blizzard/virtualisation/searx-preview.nix`, `docs/searx-kubevirt-preview.md`, `docs/kubevirt-migrations.md`: disabled host registration, exact deployment gates, service inventory and next migration prerequisites.

### Task 1: Reusable host preview disk registry

**Interfaces:** Produces safe enabled disk paths and optional preview registration input; Task 3 consumes `previewVMs.searx-preview`.

- [ ] Add fixture tests for first registration, unknown nonempty directory, restart reuse, lost DB, ancestor symlink and tampered ownership record; run `python3 -m unittest discover -s tests/actual_pilot -v`.
  Expected: new registration cases fail against the old guard.
- [ ] Implement minimal optional registration handling and typed Nix registry. Keep default guard inputs identical and production definitions untouched.
- [ ] Extend public Nix contract for enabled/disabled entries, invalid names and same production service configuration. Run the public standalone check and fixture suite.
  Expected: all fixture and Nix assertions pass.
- [ ] Document the registry boundary, format the touched files, inspect staged diff, run the staged secret/message gates, co-author commit and push `dev/kubevirt-base`; open a draft PR targeting `dev/kubevirt`.
  Expected: clean branch, passing scoped checks, no activation.

### Task 2: Complete suspended SearxNG application preview

**Interfaces:** Consumes the root path from Task 1. Produces suspended `pilot-searx-storage` and `pilot-searx` layers plus a public ConfigMap ISO with digest image/settings; Task 3 documents enabling them only after host preparation.

- [ ] Fetch apps main and create `dev/kubevirt-searxng` in the existing isolated worktree. Inspect official image/docs with isolated registry auth and XDG scratch state; record selected digest and public source revision.
  Expected: immutable official image selected without reading user credentials.
- [ ] Add failing behavior tests for suspended layers, disjoint retained PV/DV, pinned-schema VM/config disk, private forwarding peers, per-boot desired config, cached image behavior, key preservation and acyclic startup.
  Expected: failures identify absent SearxNG behavior while existing Actual checks remain meaningful.
- [ ] Implement the guest runner/bootstrap, generated cloud-init, ConfigMap desired settings, VM/service/policies and independent suspended layers. Validate supported settings against the selected image source.
- [ ] Run `nix-build tests/actual-pilot --no-out-link` and offline application smoke using isolated loopback/container state; where practical boot a disposable Debian fixture locally. Exercise settings/image change and reversal without opening real user data.
  Expected: full public suite and feasible offline smoke pass. Record exact limits of offline evidence; live Flux/CDI/network-policy acceptance remains a Blizzard deployment gate.
- [ ] Add deployment/rollback instructions, format/diff-check, co-author commit, push and open an apps draft PR against main.
  Expected: staging definitions published, both layers suspended, no running VM created.

### Task 3: Disabled host registration and migration queue

**Interfaces:** Consumes Task 1 registry and Task 2 layer names/config lifecycle. Produces a host branch stacked on `dev/kubevirt-base`.

- [ ] Create host `dev/kubevirt-searxng` from the completed base. Add a contract proving the host registration remains disabled and production Searx/all existing MicroVM definitions are unchanged.
  Expected: new declaration contract fails before registration exists.
- [ ] Add only default-false `searx-preview` host registration and the deployment runbook. Inventory all enabled MicroVM declarations into a concrete migration queue; classify state/secrets/storage/network/GPU prerequisites without reading protected secret files.
- [ ] Run the public host checks and build Blizzard's complete toplevel with `nix build .#nixosConfigurations.blizzard.config.system.build.toplevel --no-link --print-out-paths`. Compare production-related evaluated units/registry to the unchanged baseline without activation.
  Expected: complete closure builds, preview remains disabled, production workload definitions match. If external build access fails, report the specific failure without substituting evaluation for a build.
- [ ] Co-author commit, push and open a draft host PR targeting `dev/kubevirt-base`.
  Expected: useful offline preparation complete; remaining live acceptance and complex migrations are explicit.

### Task 4: Final review and handoff

**Interfaces:** Consumes all three finished branches. No runtime mutation.

- [ ] Use one fresh reviewer for the complete diff across both repos, with particular attention to the five Review Focus cases. Reproduce and fix any important finding with a failing regression and a passing suite; record minor findings.
- [ ] Check CI at the exact pushed heads; inspect and fast-forward any formatter-only commits. Ensure PRs remain draft with auto-merge disabled, canonical/compatibility umbrella refs remain equal, and no merge/activation occurred.
- [ ] Update PR descriptions with final validation and linked dependency order. Report concrete next deployment gates, storage paths and remaining complex work. Remove only this plan's ignored scratch workspace after clean final review.
  Expected: reviewable commits/PRs and truthful separation of source/build evidence from live acceptance.
