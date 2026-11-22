# Retire the Inactive KDE Configuration Option

## Approved scope

Retire `hm.desktop.kde.extraConfig` using the native removed-option module and
an actionable migration error. The option accepted an attribute set but never
applied it; no repository configuration uses it. Preserve all current KDE
behavior, services, and package selections. Keep this in a separate signed
draft PR without co-author trailers; no merge or activation is authorized.

Native Home Manager options belong directly in the existing role, host or
user override. There is no automatic configuration mapping because the old
option never applied its settings. Explicit legacy definitions, including
empty attribute sets and definitions on a disabled KDE profile, must fail.

## Steps

- [x] Add public-only contracts through the real Home Manager entry point for
  unused-option compatibility, legacy-definition rejection, native settings,
  additive packages and disabled behavior. Observe rejection cases fail
  against the original module.
- [x] Import `lib.mkRemovedOptionModule`, remove the old declaration and its
  default, and document the migration. Keep the remaining implementation.
- [x] Build the KDE, role, package, user-registry, account and formatting checks;
  compare current host settings, accounts and ordered package digests; evaluate
  all four host toplevels and obtain an independent review.

Publication follows validation: sign the commit, push
`refactor/kde-option-retirement`, and open a draft PR against
`refactor/role-defaults` without merging.

## Validation results

The original option failed exactly five desired rejection/message cases. All
ten final contracts pass through the real Home Manager entry point and the
module's removal assertion: unused-option compatibility, empty/nonempty
legacy definitions with KDE enabled/disabled, actionable migration guidance,
native settings, additive packages and disabled behavior.

All 28 host comparison digests match the role-default baseline: role/policy
and downstream settings, accounts, user toggles, ordered system package
names/versions, and Home Manager profile/package selections. Only comparison
digests are emitted; no private values are written to the repository.

The KDE, role-defaults, package-scopes, user-registry, user-accounts and
formatting checks build successfully. All four physical host system toplevels
evaluate. Focused statix/deadnix and whitespace checks pass. Independent review
found no actionable issues. No full system was built or activated.
