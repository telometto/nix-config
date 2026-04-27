## System Modules

Auto-loaded NixOS modules providing configurable system components via the
`sys.*` option namespace.

### How It Works

All `.nix` files under `modules/` are automatically imported by
[system-loader.nix](../system-loader.nix). No manual registration required —
create a module and it becomes available immediately.

### Module pattern

Every module follows the same structure:

```nix
{ lib, config, ... }:
let cfg = config.sys.<category>.<name>; in
{
  options.sys.<category>.<name>.enable = lib.mkEnableOption "...";
  config = lib.mkIf cfg.enable { ... };
}
```

Additional typed options (port, data directory, secret references, etc.) sit
alongside the mandatory `enable` flag.

---

### Directory structure

| Directory | What lives there | Example options |
|-----------|-----------------|-----------------|
| [boot/](boot/) | Plymouth splash (`sys.boot.plymouth.*`), Lanzaboote / Secure Boot (`sys.boot.lanzaboote.*`) | `sys.boot.plymouth.enable`, `sys.boot.lanzaboote.enable` |
| [core/](core/) | Cross-cutting essentials: roles, users, Home Manager integration, sops, overlays, distributed builds, nixpkgs settings, locale, packages | `sys.users.*`, `sys.home.*`, `sys.nix.*` |
| [desktop/](desktop/) | `base.nix` declares `sys.desktop.flavor` enum; `flavors/{gnome,kde,hyprland,cosmic}.nix` implement each flavour | `sys.desktop.flavor` |
| [hardware/](hardware/) | NVIDIA driver config (`sys.hardware.nvidia.*`) | `sys.hardware.nvidia.enable` |
| [networking/](networking/) | `base.nix`, `networkd.nix`, `networkmanager.nix` | `sys.networking.networkd.enable`, `sys.networking.networkmanager.enable` |
| [programs/](programs/) | System-wide programs: ssh, gaming, java, gnupg, jellyfin-gpu, nix-ld, python-venv, mtr | `sys.programs.gaming.enable` |
| [security/](security/) | `secrets.nix` declares `options.sys.secrets.*`; `ssh-hardening.nix` applies OpenSSH hardening | `sys.secrets.*` |
| [services/](services/) | ~60 service modules — see [services/README.md](services/README.md) for the full catalog | `sys.services.grafana.enable`, `sys.services.traefik.enable` |
| [storage/](storage/) | `filesystems.nix` **only** (`sys.storage.filesystems.*`) — ZFS, NFS, and sanoid live in `services/` | `sys.storage.filesystems.*` |
| [virtualisation/](virtualisation/) | `virtualisation.nix`, `microvm-base.nix` (`sys.virtualisation.*`), `libvirtd.nix`, `k3s.nix` | `sys.virtualisation.enable` |

Top-level files (not in a subdirectory):

| File | Purpose |
|------|---------|
| [role-desktop.nix](role-desktop.nix) | Bundles desktop defaults: Secure Boot, Plymouth, gaming, Flatpak, Pipewire, Tailscale, Home Manager |
| [role-server.nix](role-server.nix) | Bundles server defaults: Secure Boot, networkd, auto-upgrade, Tailscale, Home Manager |
| [home-manager-integration.nix](home-manager-integration.nix) | Wires Home Manager into the NixOS module system at the system level |

---

### Roles

Enable a role in your host configuration:

```nix
sys.role.desktop.enable = true;
# or
sys.role.server.enable = true;
```

`role-desktop.nix` enables: Secure Boot, Plymouth, gaming, Flatpak, Pipewire,
Tailscale, Home Manager.

`role-server.nix` enables: Secure Boot, networkd, auto-upgrade, Tailscale,
Home Manager.

---

### Adding a new module

1. Create `modules/<category>/<name>.nix`.
2. Define options under `options.sys.<category>.<name>.*`.
3. Implement `config = lib.mkIf cfg.enable { ... };`.
4. Done — the module auto-loads, no registration needed.

---

### Related documentation

- [services/README.md](services/README.md) — Full service catalog
- [vms/README.md](../vms/README.md) — MicroVM inventory and network topology
- [Architecture notes](../CLAUDE.md) — High-level repo architecture
