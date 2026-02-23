# Reference: Architecture & Options

Information reference for this repo’s moving parts, options, and commands.

## Flake

- Hosts are defined via `mkHost` in [flake.nix](../flake.nix). Each host includes:
  - [system-loader.nix](../system-loader.nix)
  - [host-loader.nix](../host-loader.nix) (auto-imports all `.nix` files under `hosts/<hostname>/`)
  - External modules: home-manager, sops-nix, lanzaboote, microvm

Outputs:

- `nixosConfigurations.{snowfall,blizzard,avalanche,kaizer}`
- `formatter.<system>` (treefmt wrapper)
- `checks.<system>.formatting`

## System Loader

- [system-loader.nix](../system-loader.nix) auto-imports all `.nix` files under [modules/](../modules).
- Modules typically expose `options.sys.*` with enable toggles and settings.

## Home Manager Integration

- Enabled as a NixOS module via flake.

- Control: [modules/core/home-options.nix](../modules/core/home-options.nix)

  - `sys.home.enable` (bool)
  - `sys.home.template` (attrs)
  - `sys.home.extraModules` (list)
  - `sys.home.users.<username>.{enable,extraConfig,extraModules}`

- Build logic: [modules/core/home-users.nix](../modules/core/home-users.nix)

  - Users sourced from `VARS.users` (private secrets flake)
  - Imports HM modules via [hm-loader.nix](../hm-loader.nix)
  - Adds host-wide and user@host overrides when files exist
  - Auto-enables HM desktop flavor: `hm.desktop.<flavor>.enable = true` for `kde|gnome|hyprland`

## Users

- Options: [modules/core/user-options.nix](../modules/core/user-options.nix)
  - `sys.users.<username>.enable` (bool per host)
- Accounts: [modules/core/users.nix](../modules/core/users.nix)
  - Creates `users.users.<username>` from `VARS.users` when enabled

## Roles

- Options: [modules/core/roles.nix](../modules/core/roles.nix)
  - `sys.role.desktop.enable`
  - `sys.role.server.enable`
- Config: [modules/role-desktop.nix](../modules/role-desktop.nix), [modules/role-server.nix](../modules/role-server.nix)
  - Desktop role enables networking, pipewire, printing, maintenance, tailscale, HM
  - Server role enables networkd, maintenance, auto-upgrade, HM, tailscale

## Secrets (sops-nix)

- Module: [modules/core/sops.nix](../modules/core/sops.nix)
- `sops.defaultSopsFile` points to secrets from the `nix-secrets` flake.
- Secrets for services are defined only when the service is enabled.
- Exposes runtime paths under `config.sys.secrets.*` for consumers.

## Commands

```bash
# Build a host
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel

# Switch to a host
sudo nixos-rebuild switch --flake .#<hostname>

# Format code
nix fmt

# Run checks
nix flake check
```

## Conventions

- Put new system modules under `modules/` — they’re auto-loaded.
- Put HM modules under `home/` — they’re auto-loaded by HM.
- Use `sys.*` options to opt-in features; avoid ad-hoc host edits when a module
  exists.
- Use overrides under `home/overrides/*` for per-host or per-user adjustments.

______________________________________________________________________

*This documentation was generated with the assistance of LLMs and may require
verification against current implementation.*
