# Overridable Role Preferences

## Approved scope

Use native `lib.mkDefault` for routine system-role preferences while retaining
current security priorities. Preserve the effective configuration and package
selections of all four existing hosts. Keep this separate from the user
normalization PR and publish signed commits without co-author trailers; no
merge or activation is authorized.

Desktop preferences: Plymouth enable/theme, Java, gaming/Steam, PipeWire,
printing, Flatpak, and virtualization. Server preference: Plymouth enable.
Package, font, theme-package, and overlay collections remain additive.

Secure Boot, firewall, networking, SSH/Tailscale, GnuPG, maintenance/upgrades,
Home Manager integration, and QMK device-access priorities remain unchanged.
Kaizer's printing opt-out can become an ordinary `false`; its effective value
must remain unchanged. Existing compatibility/security `mkForce` settings
are outside this cleanup.

## Steps

- [x] Capture role/preference/security/downstream digests for all four hosts;
  retain the prior account and package-selection comparison baseline.
- [x] Add behavioral checks for ordinary host preference overrides, retained
  security conflicts, inactive roles, and additive collections. Observe
  preference overrides fail against the original role definitions.
- [x] Change only the approved scalar preferences to `lib.mkDefault` and
  simplify Kaizer's printing override. Document the preference/policy split.
- [x] Run the new role-defaults check and existing package, user-registry,
  account, and formatting checks. Compare all host digests, evaluate each
  host's toplevel, and obtain an independent review.

Publication follows validation: sign the commit, push `refactor/role-defaults`,
and open a draft PR against `refactor/user-registry-normalization` without
merging.

## Validation results

The original definitions failed exactly the ten intended ordinary-override
cases. All 57 final contracts pass: ten preserved defaults, ten ordinary
overrides, 32 retained policy conflicts, and five additive/inactive-role cases.
The server Plymouth default is tested against an opposing declaration default
so deleting its explicit `false` is detected.

All 28 before/after host digests match: 12 for role preferences, policy and
downstream settings, and 16 for accounts, user toggles, ordered system package
names/versions and Home Manager profile/package selections. No private values
are written to the repository or comparison output.

The role-defaults, package-scopes, user-registry, user-accounts and formatting
checks build successfully. Each physical host's system toplevel evaluates.
Focused statix/deadnix and whitespace checks pass. Independent review's
default-coverage finding was addressed; the follow-up review found no remaining
actionable issues. No system was built or activated.
