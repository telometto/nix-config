# Package scopes and Home Manager composition

Status: approved, implemented, and validated on 2026-11-22. Activation remains
outside its scope.

## Intent and agreed direction

Make package placement predictable across roles, physical hosts, and users.
Reduce the number of switches and intermediate lists needed to install a
package, and repair extension points that currently accept configuration
without applying it.

The user chose:

- Preserve current package choices and their host/user placement. This pass
  does not trim Blizzard's GUI utilities, fonts, or development tools.
- Add `asdf-vm` to every desktop/laptop, including Kaizer, and keep it off
  servers.
- Make the existing shared `dupe-krill` intent effective for managed users,
  including users on Blizzard.
- Keep scoped files and native Nix options rather than introduce a central
  package inventory.

Existing unrelated working-tree files must remain untouched. No deployment,
secret changes, input updates, or service migrations are part of this work.

## Approaches

1. **Scoped files with native options (selected).** Keep declarations beside
   the role, host, or user they affect. NixOS's `environment.systemPackages`
   and Home Manager's `home.packages` already provide additive package lists.
   This fits the existing loaders and removes an unnecessary package wrapper.
1. **Central package inventory.** Put role, host, and user mappings in one
   file and distribute them through a custom module. This offers a single
   overview but adds a schema and another translation step. It was not selected.
1. **More custom package options.** Introduce `sys.packages.*` and matching
   user options. These largely forward native options and increase the
   interface maintainers must learn. This is not needed for the requested
   scopes.

## Package placement

| Scope | File | Native option |
|---|---|---|
| Every physical host | `modules/core/packages.nix` | `environment.systemPackages` |
| Every managed user | `home/packages.nix` | `home.packages` |
| Every host in a role | `modules/role-<role>.nix` | `environment.systemPackages` |
| Every managed user in a role | `home/overrides/role/<role>.nix` | `home.packages` |
| One host, system packages | `hosts/<host>/packages.nix` | `environment.systemPackages` |
| Every managed user on one host | `home/overrides/host/<host>.nix` | `home.packages` |
| One user on every host | `home/overrides/user/<user>.nix` | `home.packages` |
| One user on one host | `home/overrides/user/<user>-<host>.nix` | `home.packages` |

Here, a managed user is an enabled normal user from `VARS.users` for whom
Home Manager is enabled. Service accounts and unmanaged users are outside
the user package scopes. System packages are available to all users.

Desktop and laptop already share the `desktop` role. Snowfall, Avalanche,
and Kaizer select it; Blizzard selects `server`. No new role is needed.

`asdf-vm` goes in the desktop role's system package list. Its current duplicate
host entries are removed. `dupe-krill` goes in the unconditional shared
`home/packages.nix`. Remove `home/programs/packages.nix` and its unused
`enable`/`additionalPackages` interface; there are no callers in the checkout.
The auto-loader picks up the replacement file without a manual import.

Flatten the small host package lists, remove empty/comment-only category
scaffolding, and remove declarations already supplied at the same system
scope (`p7zip` on Kaizer and `sbctl` on Avalanche). Keep meaningful categories
in the larger common system list. Remove Blizzard's unreachable Helm binding
without installing Helm; that binding is not currently part of its package
list. Other duplicate selections remain in their existing scopes when moving
them would give packages to additional hosts or users.

Installing `asdf-vm` does not run it, install language runtimes, or migrate
existing asdf state. Shell integration or storage changes would require
separate evidence about the user's current setup.

## Repair Home Manager composition

`modules/core/home-users.nix` has three reversed `lib.attrByPath` calls for
per-user overrides and another for the system user's home directory. Replace
these with ordinary attribute lookups and explicit defaults. This restores
`sys.home.users.<name>.enable`, `extraModules`, and `extraConfig`, and respects
a nonstandard NixOS home directory when private user metadata has no home.

Replace the raw `lib.recursiveUpdate` fold with native module composition.
Keep the current role/host/user/user-and-host import selection, template
imports, and extra module interfaces. The template, per-user configuration,
automatic desktop defaults, and username/home defaults become separate Nix
module definitions instead of overwriting one another before evaluation.

Consequences are deliberate:

- Package lists from multiple scopes and extension points combine.
- Explicit desktop settings beat the automatic `mkDefault` selection.
- The builder's existing metadata-first fallback is preserved, while fixing
  the system-user lookup. In an integrated profile, Home Manager supplies
  the NixOS account's home directory at ordinary priority, above these
  fallback defaults. Preserve that account authority; do not relocate homes.
- Conflicting scalar assignments follow normal Nix option priorities.
  Import order is not an implicit precedence ladder; shared scalar defaults
  should use `mkDefault`, and conflicting plain assignments should be reported.
- No new configuration namespace or private-data schema is introduced.

Keep package additions associated with configured programs in their existing
modules. In particular, make `hm.programs.terminal.extraPackages` contribute
to `home.packages`. Honor `hm.programs.terminal.zellij.enable` and give it an
explicit default of `true`, preserving the currently effective default while
allowing an explicit `false` to work. There are no current callers setting
this switch.

## Evidence from the audit

The scan covered package declarations and loaders across all four hosts,
the system and Home Manager core modules, the user overrides, and static
dead-code analysis across `modules`, `home`, `hosts`, `vms`, `containers`,
and `lib` (268 Nix files). Selected service, container, VM, and CI interfaces
were inspected for similar patterns; this is not a runtime acceptance test
of every workload.

Public-only probes use the exact public input revisions in `flake.lock` and
synthetic user data. They do not fetch or print private `VARS` values.

Confirmed findings:

| Finding | Evidence / consequence |
|---|---|
| Shared `dupe-krill` never enabled | The actual package module emits no package by default and emits it when explicitly enabled; no repository caller enables it. Snowfall's active system and Zeno profiles also lack its executable. |
| Per-user HM interface ignored | The actual builder ignores per-user package additions and the disable flag because its attribute lookups use the wrong argument order. Extra-module selection uses the same erroneous lookup. |
| Automatic desktop overwrites explicit choice | A synthetic template setting KDE to false is replaced by the builder's automatic true default before module priority can apply. |
| Package additions can overwrite each other | The builder combines raw attribute sets with `recursiveUpdate`, which replaces lists instead of applying Nix option merging. The broken user lookup currently hides part of this second problem. |
| Terminal additions and Zellij switch ignored | Evaluating the actual terminal module with an extra package and `zellij.enable = false` leaves the package absent and Zellij enabled. |
| Package scaffolding hides real content | Empty/unused categories exist in host lists; Blizzard's Helm list is defined but omitted. |

`deadnix` reported unused code in 35 files; most findings are unused arguments,
so a blanket lint rewrite would add review noise. `statix check` returned
success for each of the six source trees. Blizzard's live SSH inspection was
blocked by a Tailscale authentication check; its installed profile has not
been independently verified. Full private host evaluation has not been run
at the design stage.

## Validation and acceptance

Add focused public-only checks at the real module/builder interfaces, using
synthetic users and small fixtures. Avoid tests that merely search source
text or assert formatting.

- Desktop role supplies `asdf-vm`; server role does not. Retain a host-level
  package-name comparison for the structural list cleanup, with only the
  agreed asdf change allowed.
- Shared `dupe-krill` reaches managed users without a separate enable flag.
- Role, host, user, and user-and-host selections combine without leaking
  targeted additions to another user/host. Test template and per-user
  package additions together.
- Per-user extra modules are applied, disabled user profiles are omitted,
  a custom system home directory is honored through the real NixOS/HM
  integration (including conflicting metadata), and explicit desktop opt-out
  survives automatic selection.
- Terminal package additions work; Zellij keeps its effective default and
  honors an explicit disable.
- Wire the focused checks into flake checks without changing the private
  input or bypassing normal CI.
- Run targeted formatting, parse/static checks, focused evaluations, and
  `git diff --check`. Attempt broader evaluation only when private-input
  access is available; report any missing coverage accurately.

Document the placement table, additive list behavior, scalar priorities,
and the repaired per-user interfaces in the relevant READMEs. No system
activation is authorized.

## Implementation results

- All 36 focused contracts pass, including real pinned NixOS/Home Manager
  integration for account homes, package composition, and profile opt-out.
- The `package-scopes` and locked repository formatting flake checks build.
- The repository's CI output-evaluation script passes locally for all
  32 NixOS configurations, all 29 declared checks, the formatter,
  and the development shell. This evaluates output derivations; it does not
  build every system or run every runtime fixture.
- All 31 CI control tests pass. Changed Nix files parse, formatting and
  `git diff --check` pass, and the static scan removes 11 existing dead-code
  findings without introducing any.
- The captured system package-name sets have no removals. Only Kaizer gains
  `asdf-vm`; Snowfall and Avalanche already had it. Shared Home Manager users
  gain `dupe-krill` as agreed.
- The fresh review's account-home documentation/test gap was corrected with
  real integration coverage. Existing NixOS account homes remain authoritative.
- The implementation is prepared on `refactor/package-scopes` for a pull
  request. No activation, full host build, or live profile acceptance was
  performed; unrelated user files are preserved.

## Other opportunities, deferred from this pass

1. **User registry normalization:** username mapping is repeated in
   `user-options.nix`, `users.nix`, and `home-users.nix`. A shared helper could
   reduce schema drift, but account validation and private metadata deserve
   a separate focused change.
1. **Role defaults:** the role bundles mostly use plain assignments, so host
   exceptions often need `mkForce`. Distinguish overridable preferences from
   enforced security policy before converting assignments mechanically.
1. **Unused KDE extension point:** `hm.desktop.kde.extraConfig` is declared
   but unused and has no callers. Retire it or define a precise target in a
   separate interface cleanup; its intended semantics are currently unclear.
1. **Inventory and documentation drift:** the older architecture risk list
   still proposes a role exclusivity assertion that already exists, and
   lists old VM counts. Current source deliberately reserves the
   `flaresolverr` registry entry for the service embedded in Prowlarr; it does
   not justify inventing a new standalone deployment.
1. **Shared packages across only some desktops:** Snowfall and Avalanche
   share several explicit selections. Moving these to the desktop role
   would also install them on Kaizer. Preserve the existing placement until
   that expansion is requested, rather than add another profile layer now.

## Builder discretion

The implementer may choose fixture layout, check names, and the smallest
native module composition that satisfies the above contracts. Preserve
existing public option names except the unused shared-package wrapper
explicitly retired here. Do not expand into service, firewall, storage,
kernel, credential, or deployment changes.
