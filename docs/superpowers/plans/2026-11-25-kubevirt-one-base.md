# One shared migration base Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline, then one fresh whole-change reviewer. The user approved this correction; do not request the same permission again.

**Goal:** One actual PR base per repository for all seventeen services, preserving #5894, existing service PRs, forward history and production.

**Architecture:** Absorb shared host commits into synchronized umbrella refs; separate SearxNG from the application common tree; bring the common head into each service branch with normal forward commits and retarget PR metadata.

**Tech Stack:** Git, GitHub, Nix, existing public Python/Kustomize contracts.

**Spec:** ../specs/2026-11-25-kubevirt-one-base-design.md

## Global Constraints

- No main merge, activation, deployment, live API, production data/secret access or route changes.
- Preserve #5894 draft/unmerged; only foundation absorption and common ancestry updates are approved.
- No force push/rebase, service-to-service merge, unrelated edits, or branch deletion.
- Co-author all new commits; stage explicit paths; tool state and handoffs stay in task tmp/XDG locations.
- Host PR base dev-kubevirt; canonical dev/kubevirt synchronized. Apps PR base dev/kubevirt-groundwork, umbrella #14 base main.

## Review Focus

- Alias SHA equality alone must not leave GitHub dependency links disconnected.
- Shared app source must not silently include SearxNG or drop its real service payload.
- Merging the common source must not pull unrelated service directories into a service PR.
- PR retarget ordering must not accidentally absorb the app umbrella into SearxNG.
- New handoffs must use current heads/ancestry, replacing stale direct-parent assumptions.

### Task 1: Prepare and verify the shared bases

Files: this spec/plan, docs/kubevirt-groundwork.md, application shared README, app default.nix/layers/namespaces, removed Searx-only app source/tests.

- [ ] Snapshot current local/remote refs and require clean isolated worktrees.
- [ ] Observe the common-app separation check fail because Searx is present.
- [ ] Prepare host umbrella and corrected docs; prepare app common-only tree, keeping generic multi-service test support.
- [ ] Run public host/app checks; co-author commits; record exact base heads.

### Task 2: Preserve and align all service branches

Files: service branch histories, SearxNG app payload restoration, no unrelated runtime edits.

- [ ] Restore SearxNG's exact public implementation on its own branch above the app common head.
- [ ] Bring each common head into each service branch without rewriting old commits.
- [ ] Assert old heads remain ancestors and PR diffs are owned-only; compare runtime payloads with the recorded original trees.
- [ ] Run existing relevant contracts on actual branches and a combined public-source overlay, without a branch merge into either umbrella.

### Task 3: Publish the approved correction

Interfaces: exact-head guards, normal atomic host-alias push, GitHub base_branch metadata.

- [ ] Retarget #7320/#7324 to the actual #5894 head, and apps #14 to main before any Searx branch push.
- [ ] Publish verified bases and aligned service heads; preserve all draft/no-auto-merge states.
- [ ] Retarget seventeen host and seventeen app service PRs to their single common base.
- [ ] Verify foundation absorption/closure and keep #5894/#14 unmerged into main.

### Task 4: Final evidence and handoff

- [ ] Fresh whole-change review; fix material defects and rerun affected checks.
- [ ] Build final Blizzard base, verify unchanged selected production payloads, inspect CI at exact heads.
- [ ] Update temporary handoffs, receipt index and shared guidance; verify all refs/bases/source separation.
- [ ] Report the actual common branches and no activation/main merge.
