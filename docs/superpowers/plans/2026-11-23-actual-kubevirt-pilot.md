# Actual KubeVirt Pilot Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline, followed by one fresh whole-change review. The user has authorized implementation and requires stopping before activation.

**Goal:** Prepare a reproducible private Actual pilot alongside Blizzard's production MicroVMs.

**Architecture:** NixOS runs isolated k3s with bundled networking and seeds missing Flux objects. A new self-contained homelab-apps cluster tree owns operators, storage, the VM, and Flux itself. Separate retained disks and a fail-closed guest setup protect data.

**Tech Stack:** NixOS, k3s 1.35.10+k3s1, Flux 2.10.1, KubeVirt 1.9.1, CDI 1.66.1, Debian 13, Actual 26.11.0, Python, Kustomize.

**Spec:** `docs/superpowers/specs/2026-11-23-actual-kubevirt-pilot-design.md`

## Global Constraints

- Never activate, reboot, stop, or change a live service in this task.
- Preserve production MicroVMs, ingress, old pilot state, and existing checkouts.
- Do not inspect existing secret files, encrypted bundles, kubeconfigs, or private keys.
- Host state `/var/lib/rancher/k3s-actual-pilot`; new disks `/flash/enc/vms/kubevirt-pilot/actual/`.
- Pod CIDR `10.44.0.0/16`, Service CIDR `10.45.0.0/16`, DNS `10.45.0.10`.
- Pilot GitOps root `clusters/blizzard-actual-pilot/`; public HTTPS source.
- Actual VM/namespace `actual-pilot`, 1 vCPU, 1 GiB guest RAM, retained 20 GiB root and 10 GiB data disk, ClusterIP TCP 5006 only.
- Final handoff reports local validation separately from deployment/runtime acceptance.

## Review Focus

- Starting the new cluster must not read old manifests/config or take production ports.
- Partial bootstrap recovery must not overwrite newer Flux-managed objects.
- Guest setup must reject an unexpected disk/filesystem and start Actual only after data is mounted.
- GitOps reconciliation/pruning must not erase persistent volumes or reset desired power state.
- NetworkPolicy must allow real bootstrap/import/DNS paths while denying production private networks; evaluate port-forward separately.

### Task 1: Pin dependencies and validate isolated host configuration

**Files:** `modules/virtualisation/actual-pilot.nix`, `hosts/blizzard/virtualisation/actual-pilot.nix`, `hosts/blizzard/blizzard.nix`, `tests/actual-pilot.nix`, `tests/actual-pilot-check.nix`, `flake.nix`, public bootstrap pins.

**Interfaces:** Consumes locked public nixpkgs. Produces opt-in `sys.virtualisation.actualPilot.enable`, generated config, new paths, scoped firewall rules, and bootstrap unit. Other hosts remain disabled.

- [x] Write focused NixOS evaluation assertions for disabled/default and enabled cases, safe ports/paths, resource isolation, and no changes to host ingress/MicroVM settings.
- [x] Run assertions against the unimplemented module; expect failure due to missing pilot option/module.
- [x] Inspect pinned upstream service, freeze public release assets/hashes, and implement the opt-in module and Blizzard wiring. Keep shared k3s defaults unchanged.
- [x] Run focused public evaluation/build and syntax checks; expect all assertions true without loading nix-secrets.

### Task 2: Seed Flux without overwriting desired state

**Files:** `modules/virtualisation/scripts/actual_pilot_bootstrap.py`, `tests/actual_pilot/test_bootstrap.py`, host module bootstrap wiring.

**Interfaces:** Consumes pinned Flux components and a generated GitRepository/root Kustomization. Creates only absent API objects and waits for controller readiness; has bounded requests/retries.

- [x] Write executable boundary tests: fresh seed, existing newer objects, partial seed, API failure, create race, and request failure propagation.
- [x] Run them; expect missing implementation failure.
- [x] Implement create-only bootstrap with CRD establishment ordering and explicit timeouts. Do not stage manifests in k3s auto-apply.
- [x] Run bootstrap suite and evaluated unit checks; expect success and no replacement of existing objects.

### Task 3: Implement the isolated GitOps tree and guest

**Files:** New `clusters/blizzard-actual-pilot/` tree in isolated homelab-apps checkout; its lock/provenance file, vendored operator/Flux assets, provisioning payload, and tests.

**Interfaces:** Consumes Task 1 paths/CIDRs and Task 2 root. Produces dependency-ordered Flux layers, retained PVs/DataVolumes, VM, Service, and scoped policies.

- [x] Write tests that build and validate the actual manifests and exercise fail-closed disk decisions/provisioning behavior. Expect failure before the tree exists.
- [x] Vendor pinned public release manifests and record verified hashes. Pin the Debian image and Actual registry digest.
- [x] Implement operators/CRs, storage, non-secret guest provisioning, VM with Always/Halted Git power control, private ClusterIP, and isolated policies.
- [x] Build every Kustomization, validate custom resources with the vendored CRD schemas, and run provisioning tests. Expect no legacy-root inclusion or public exposure.

### Task 4: Add runbooks, checks, and review the complete result

**Files:** `docs/actual-kubevirt-pilot.md`, documentation indexes, public CI/check wiring, companion README/runbook.

**Interfaces:** Consumes finished host config/manifests. Produces reproducible local verification and reviewable future activation/acceptance commands; runs none of those live commands.

- [x] Document source publication prerequisites, private access, Git power control, diagnostics, retained storage, quiesced backup/restore, coexistence checks, and activation/reboot boundaries.
- [x] Run all relevant focused checks and formatting. Record any unavailable full private host evaluation/build explicitly.
- [x] Request one fresh whole-change review of both checkouts and approved spec; fix material issues with meaningful regression checks.
- [x] Leave implementation reviewable and unactivated, with exact paths, evidence, and remaining live acceptance gates. Do not push, merge, or publish without a need in the user's authorized implementation scope.
