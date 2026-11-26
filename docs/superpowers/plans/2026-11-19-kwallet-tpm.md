# TPM-backed KWallet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Reusable TPM-backed KWallet unlock with Kaizer enabled and local enrollment.

**Architecture:** A root-only PAM bridge supplies an enrolled credential to
KDE's existing auth hook, then clears its token. Missing enrollment and TPM
failures leave automatic login and manual wallet unlocking available.

**Tech Stack:** NixOS modules, Linux PAM/C, Python stdlib, systemd-creds.

**Spec:** ../specs/2026-11-19-kwallet-tpm-design.md

## Global Constraints

- No real secrets, wallet access, private inputs, activation or deployment.
- Publish only this feature on `security/kwallet-tpm-unlock`; no merge or co-authors.
- Plasma 6, SDDM autologin, per-user allowlist, root-only credentials.
- Explicit `host+tpm2` protection; default PCRs 4 and 7; no weaker fallback.
- Normal password login, existing PAM tokens and unrelated local edits remain intact.

## Review Focus

- A TPM failure must neither prompt at the greeter nor change a denied login.
- A decrypted token must not reach later auth rules or another user's session.
- Encryption/write failure must preserve the previous credential and hide output.
- A host update must not silently reseal for a changed boot policy.
- Module reuse must not enable other hosts or require private input evaluation.

### Task 1: Credential handoff and enrollment package

**Files:** Create `packages/kwallet-tpm/{default.nix,pam_kwallet_tpm.c,enroll.py}`
and `tests/{kwallet_tpm_test.py,kwallet_tpm_pam_fixture.c}`.

**Interfaces:** Package accepts public allowedUsers and pcrs. Produces
`lib/security/pam_kwallet_tpm.so` (inject/clear PAM auth phases) and
`bin/kwallet-tpm-enroll USER`. Runtime path is
`/var/lib/kwallet-tpm/USER.cred`; credential name is `kwallet-tpm-USER`.

- [x] Write fixture tests for the security limits listed above, using real PAM
  and synthetic ciphertext/plaintext; run and observe failure before the package exists.
- [x] Implement bounded, private decryption and token ownership/cleanup.
- [x] Implement interactive enrollment, prerequisite checks and atomic writes.
- [x] Run the full fixture suite until green; compile C with warnings as errors.

### Task 2: Reusable module, Kaizer enablement and CI

**Files:** Create `modules/security/kwallet-tpm.nix`,
`hosts/kaizer/kwallet-tpm.nix`, `tests/kwallet-tpm.nix`; update
`flake.nix`, `.github/scripts/flake_ci.py` and its affected tests as needed.

**Interfaces:** Consume the package; expose `sys.security.kwalletTpm`
enable/users/pcrs. Produce only the autologin PAM handoff, local enrollment
command and private state directory. The enabled host supplies only its users.

- [x] Write public module-evaluation assertions for disabled/enabled/reused
  hosts, ordered PAM rules, missing enrollment, invalid policy/users and
  unchanged regular-login settings; run before module implementation.
- [x] Implement the module and Kaizer's opt-in, then register its check.
- [x] Build the public-only check and run CI classifier tests.

### Task 3: User instructions and publication

**Files:** Create `docs/kwallet-tpm.md`; update relevant README indexes.

**Interfaces:** Document local password restoration, enrollment, post-update
re-enrollment, failure recovery, reuse and the physical-access boundary.

- [x] Write exact local commands that never put a password in command arguments
  or ask the user to share it. Do not execute enrollment or access the wallet.
- [x] Format changed files, inspect the scoped diff, and independently review.
- [x] Fix confirmed issues, rerun relevant checks, and scan only staged additions.
- [ ] Commit with no co-author trailers, push the feature branch, create and
  attach an unmerged PR, and report validation limits and local enrollment steps.

## Review outcome

The independent review found policy changes could reuse an older enrollment,
TPM cleanup could outlive the PAM deadline, post-replacement interruption text
was misleading, and the rendered PAM include chain needed a direct assertion.
All four were repaired. Synthetic regression tests observed the first three
fail before the repairs. The public check now forces the rendered auth rules
and complete session include chain.

The decryptor is owned and reaped by an orphaned worker. The PAM path uses a
pidfd to cancel it and never waits for TPM cleanup. The credential's
authenticated name includes the canonical PCR set, so changed policy requires
local re-enrollment. KDE still retains the password copy its session hook needs.
