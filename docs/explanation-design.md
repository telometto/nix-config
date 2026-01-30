# Explanation: Design & Rationale

This repo aims for fast onboarding and consistent configuration across machines by standardizing on loaders, roles, and secrets.

## Loaders

- System loader ([system-loader.nix](../system-loader.nix)) removes manual imports. Any `.nix` under [modules/](../modules) is in scope, so features are discoverable and uniformly available.
- Home loader ([hm-loader.nix](../hm-loader.nix)) provides the same for Home Manager while deliberately excluding host/user overrides so those remain opt-in.

Trade-offs:

- Pros: Less boilerplate, fewer import mistakes, easy module growth.
- Cons: Requires naming discipline and clear option namespaces (`sys.*`).

## Roles

- Roles encapsulate bundles of sensible defaults for desktops and servers. Enabling a role flips multiple features and sets a baseline (e.g., networking, audio stack, maintenance). This keeps host files succinct while remaining override-friendly.

## Users via `VARS`

- Users and properties (shell, groups, keys) are defined centrally in a private secrets flake (`nix-secrets`). Per-host enable toggles (`sys.users.<username>.enable`) prevent accidental account sprawl and make user presence explicit per machine.

## Home Manager

- Integrates at the NixOS level for each enabled user, merging a shared template, optional extra modules, and both host-wide and user@host overrides. Desktop flavors auto-signal HM to switch on relevant pieces.

## Secrets

- `sops-nix` config defines secrets only when their corresponding services are enabled. This removes dangling secret references and simplifies onboarding: turn a service on, and its secrets mapping appears.

## Why Flakes

- Reproducibility across hosts, clean input pinning, and ergonomic per-host switching (`nixos-rebuild --flake .#<hostname>`). Checks and formatters are exposed as flake outputs.

## Evolving the Repo

- Add modules under `modules/` and expose options under `sys.*`.
- Prefer role additions when defaults suit classes of machines.
- Keep sensitive data out of this repo; extend `nix-secrets` (`VARS`) when
  needed.

______________________________________________________________________

*This documentation was generated with the assistance of LLMs and may require
verification against current implementation.*
