# Package Scopes Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this
> approved plan in this session. Track completion below and in the task ledger.

**Goal:** Predictable additive package scopes with working Home Manager user
extension points and fewer configuration layers.

**Architecture:** Keep native NixOS and Home Manager package lists at their
existing scopes. Compose Home Manager definitions through the module system,
and retire the unused shared-package wrapper.

**Tech Stack:** NixOS, Home Manager, Nix module evaluation, treefmt/nixfmt.

**Spec:** `docs/superpowers/specs/2026-11-22-package-scopes-design.md`

## Global Constraints

- Preserve package choices and placement except desktop `asdf-vm` and shared
  `dupe-krill`.
- Preserve unrelated untracked files and private-data schemas.
- Use synthetic data and locked public inputs for focused tests.
- No deployment, secret changes, input updates, or service migrations.
- Publish signed commits without co-author trailers and open a pull request;
  do not merge it.

## Review Focus

- A user opt-out must omit that profile without affecting another user.
- Template and per-user package/module additions must combine.
- Custom home directories and explicit desktop opt-outs must be respected.
- Role, host, and user imports must stay targeted when a user/host changes.
- Structural package cleanup must preserve effective selections on every host.

### Task 1: Repair Home Manager composition and terminal controls

**Files:** `modules/core/home-users.nix`, `home/programs/terminal.nix`,
`tests/home-composition.nix`, `tests/terminal-options.nix`.

**Interfaces:** Consume `sys.home.template`, `sys.home.users.*`, role/host/user
imports and terminal options. Produce native additive HM module definitions.

- [x] Add public-only behavioral probes for combined package additions,
  per-user modules and opt-out, custom homes, desktop override, terminal extras,
  and Zellij default/disable. Run them and observe the confirmed regressions.
- [x] Correct attribute lookups; replace the raw recursive update with module
  composition; wire terminal extras and preserve Zellij's effective true default.
- [x] Re-run all focused cases; every contract must be true.

### Task 2: Simplify package placement

**Files:** `modules/role-desktop.nix`, `home/packages.nix`,
`home/programs/packages.nix` (remove), `hosts/*/packages.nix`,
`tests/package-scopes.nix`, `flake.nix`.

**Interfaces:** Task 1 guarantees additive HM lists; this task supplies ordinary
package declarations and public flake checks.

- [x] Add role membership/shared package tests and observe missing desktop
  `asdf-vm`/unconditional shared package behavior before changing declarations.
- [x] Move asdf to the desktop role, replace the shared wrapper with a native
  shared list, and flatten host lists/remove redundant or unreachable entries.
- [x] Wire focused checks into the flake. Re-run them and compare the captured
  system package-name baseline: only Kaizer gains asdf; other sets stay equal.

### Task 3: Documentation, static verification, and final review

**Files:** `README.md`, `home/README.md`, `hosts/README.md`,
`modules/README.md`, `modules/core/home-options.nix`, approved design/plan.

**Interfaces:** Document the native scopes and repaired extension points from
Tasks 1–2; preserve ordinary Nix scalar priority semantics.

- [x] Document package placement and template/list/scalar composition, including
  the retired package wrapper and focused public-only check invocation.
- [x] Run focused checks, baseline comparison, changed-file formatting,
  parse/static checks, and `git diff --check`.
- [x] Attempt normal flake/host evaluation without changing private inputs;
  accurately report any unavailable access or other pre-existing failure.
- [x] Obtain a fresh whole-change review, resolve material findings, and report
  changes, verification limits, and deferred audit opportunities.
