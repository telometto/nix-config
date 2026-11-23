# User Registry Normalization

## Contract

Extract the repeated conversion of role-keyed `VARS.users` data into one pure
helper, `lib/user-registry.nix`, used by `user-options.nix`, `users.nix`, and
`home-users.nix`. Preserve current behavior and package selections. This is
a follow-up to the package-scope cleanup, based on `refactor/package-scopes`.

The helper accepts `{ lib, users }` and returns:

- `records`: every original record in attribute-name order, retaining
  `roleName`, `userData`, raw `username`, and optional `uid`.
- `byUsername`: the original payload keyed by a nonempty string login, or
  the original role key for a missing, empty, or non-string login. The first
  record wins a collision, matching the existing `listToAttrs` behavior.
- `isValidUsername`: the existing nonempty-string predicate.

Keep host enablement, normal-user filtering, credentials/UID validation,
account generation, and Home Manager policy in their owning modules. In
particular, duplicate or malformed records must remain available to all
existing assertions. Do not change private data, account homes, package
placement, or activation behavior. Preserve unrelated working-tree files.

## Implementation

- [x] Capture before-refactor digests of account fields, user toggles, system
  package selections and managed-home identity/package selections for all
  four hosts. Store only digests outside the repository.
- [x] Add synthetic characterization coverage for role/login differences,
  optional UIDs, invalid/duplicate logins, host enablement, normal-user HM
  filtering, account groups/keys, and host-local effective UID validation.
- [x] Add the pure helper and test its fallback, collision ordering, record
  retention, and lazy payload handling.
- [x] Replace the three local normalizations with helper consumers. Retain
  validation messages and evaluation order; system generation filters the
  complete record list before producing a username-keyed account map.
- [x] Add the public `user-registry` flake check and document the helper.
- [x] Verify the new check and existing package/composition checks, compare
  all host digests, and run relevant formatting/static checks and broader
  host evaluation. Obtain an independent review and fix material findings.

## Publication

Use the repository's `refactor/...` naming convention. Commits use the
configured signing identity and contain no co-author trailer. Keep the work
separate from the package-scope PR unless directed otherwise. Do not merge
either PR or activate any host.

## Results

- All 20 characterization cases passed before extraction; all 32 helper and
  consumer cases pass after extraction.
- The existing 36 package/composition cases, real user-account check, and
  locked repository formatting check build successfully.
- All four host toplevel derivations evaluate. All 16 before/after digests
  match for account fields, user toggles, ordered system package selections,
  and managed-home identity/package selections. No private values are
  exported into test fixtures or repository files.
- Changed Nix files parse; deadnix, relevant statix checks, and whitespace
  validation pass. Independent review found no actionable issues.
- Existing whitespace-name and fallback-collision behavior is intentionally
  retained. No activation, merge, or package-policy changes are included.
