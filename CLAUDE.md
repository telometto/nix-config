# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

> **Note:** `nixos-rebuild`, `nix build`, and `nix flake check` all pull the
> private `nix-secrets` flake via SSH (`git+ssh://git@github.com/telometto/nix-secrets`).
> They will fail with a publickey error without the corresponding SSH key.
> CI is the source of truth for build validation.

```bash
# Apply configuration to current host
sudo nixos-rebuild switch --flake .#<hostname>

# Build without switching
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel

# Format all files (nixfmt, shfmt, yamlfmt, mdformat, jsonfmt, ruff)
nix fmt

# Run flake checks (includes format check)
nix flake check
```

Hosts: `snowfall` (desktop/KDE), `blizzard` (server), `avalanche` (desktop/GNOME), `kaizer` (desktop/KDE)

## Architecture

### Auto-loading

The repo uses three loaders that eliminate manual imports:

- **`system-loader.nix`** — recursively imports every `.nix` file under `modules/`. Any new file there is immediately available.
- **`hm-loader.nix`** — recursively imports every `.nix` file under `home/`, excluding `overrides/host/` and `overrides/user/` (those are opt-in).
- **`host-loader.nix`** — imports every `.nix` file under `hosts/<hostname>/` for the active host.

### Option namespaces

- `sys.*` — NixOS system options (defined in `modules/`)
- `hm.*` — Home Manager options (defined in `home/`)

### Module pattern

All modules follow the same structure:

```nix
{ lib, config, ... }:
let cfg = config.sys.<category>.<name>; in
{
  options.sys.<category>.<name>.enable = lib.mkEnableOption "...";
  config = lib.mkIf cfg.enable { ... };
}
```

### Roles

Two role files bundle defaults for classes of machines:

- `modules/role-desktop.nix` — enables Secure Boot, Plymouth, gaming, Flatpak, Pipewire, Tailscale, HM
- `modules/role-server.nix` — enables Secure Boot, networkd, auto-upgrade, Tailscale, HM

Enable in a host file: `sys.role.desktop.enable = true;`

### Users and secrets

- User definitions (shell, groups, SSH keys) live in the private `nix-secrets` flake as `VARS.users.*`.
- Per-host presence is controlled by `sys.users.<username>.enable`.
- Secrets use `sops-nix`; the module in `modules/core/sops.nix` defines secrets only when their service is enabled, so no dangling references.
- Runtime secret paths are exposed under `config.sys.secrets.*`.

### Home Manager integration

- Integrated at NixOS level via `modules/core/home-users.nix`.
- Setting `sys.desktop.flavor = "kde"` (or `gnome`/`hyprland`) automatically sets `hm.desktop.<flavor>.enable = true`.
- Override precedence (low → high): module defaults → base template → auto desktop config → host override → user@host override → per-user `extraConfig`.

### Override system

| File pattern | Scope |
|---|---|
| `home/overrides/host/<hostname>.nix` | All users on that host |
| `home/overrides/user/<username>-<hostname>.nix` | Specific user on specific host |

### Containers (quadlet-nix)

- Container definitions live in `containers/` as Home Manager modules.
- Rootless: use `virtualisation.quadlet.containers` in HM config; user needs `linger = true` and `autoSubUidGidRange = true`.
- Rootful (inside MicroVMs): use `virtualisation.quadlet.containers` at system level.
- Requires `sys.virtualisation.enable = true` on the host.

### MicroVMs

- `vms/vm-registry.nix` — single source of truth for CID, MAC, IP, memory, vCPU per VM.
- `vms/mkMicrovmConfig.nix` — helper that generates common network/storage config from a registry entry.
- `vms/base.nix` — shared hardened base (SSH keys, admin user, firewall).

### Lib helpers

- `lib/traefik.nix` — `mkSecurityHeaders`, `mkRoutes`, `mkReverseProxyOptions`, `mkTraefikDynamicConfig`, `mkCfTunnelAssertion`
- `lib/constants.nix` — shared strings: `tailscale.suffix` (loaded as `consts` in flake.nix)
- `lib/grafana-dashboards.nix` — `fetchGrafanaDashboard`, pre-configured community and custom dashboard sets
- `lib/grafana.nix` — panel-builder DSL: `mkDashboard`, `mkTimeseries`, `mkGauge`, `mkStat`, `mkBargauge`, `mkRow`, `mkTarget`

## Adding things

| Task | Location | Notes |
|---|---|---|
| New system feature | `modules/<category>/<name>.nix` | Auto-loaded; use `sys.*` options |
| New HM feature | `home/<category>/<name>.nix` | Auto-loaded; use `hm.*` options |
| New host | `hosts/<hostname>/` | Register in `flake.nix` via `mkHost` |
| Per-host HM tweak | `home/overrides/host/<hostname>.nix` | Imported explicitly by HM |
| Per-user HM tweak | `home/overrides/user/<user>-<host>.nix` | Imported explicitly by HM |
| Sensitive data | `nix-secrets` flake (`VARS`) | Never commit to this repo |
