## System Modules

Auto-loaded NixOS modules providing configurable system components via the
`sys.*` option namespace.

### How It Works

All `.nix` files in this directory are automatically imported by
[system-loader.nix](../system-loader.nix). No manual registration required—just
create a module and it becomes available.

### Directory Structure

| Directory | Purpose | Example Options |
|-----------|---------|-----------------|
| [boot/](boot/) | Boot configuration | `sys.boot.lanzaboote.enable`, `sys.boot.plymouth.enable` |
| [core/](core/) | Essential system config | `sys.users.*`, `sys.home.*`, `sys.nix.*` |
| [desktop/](desktop/) | Desktop environments | `sys.desktop.flavor` |
| [hardware/](hardware/) | Hardware-specific config | `sys.hardware.nvidia.enable` |
| [networking/](networking/) | Network configuration | `sys.networking.networkmanager.enable` |
| [programs/](programs/) | System-wide programs | `sys.programs.gaming.enable` |
| [security/](security/) | Security hardening | SSH hardening, secrets management |
| [services/](services/) | Self-hosted services | `sys.services.grafana.enable` |
| [storage/](storage/) | Storage: ZFS, NFS, sanoid | `sys.storage.zfs.enable` |
| [virtualisation/](virtualisation/) | VM and container support | `sys.virtualisation.enable` |

### Roles

Two role modules bundle sensible defaults:

- [role-desktop.nix](role-desktop.nix) — Desktop workstation defaults
  (Secure Boot, Plymouth, gaming, Flatpak, Pipewire)
- [role-server.nix](role-server.nix) — Server defaults
  (Secure Boot, networkd, auto-upgrade, minimal services)

Enable a role in your host configuration:

```nix
sys.role.desktop.enable = true;
# or
sys.role.server.enable = true;
```

### Module Pattern

Each module follows a consistent structure:

```nix
{ lib, config, ... }:
let
  cfg = config.sys.<category>.<name>;
in
{
  options.sys.<category>.<name> = {
    enable = lib.mkEnableOption "Feature description";
    # Additional options...
  };

  config = lib.mkIf cfg.enable {
    # NixOS configuration when enabled
  };
}
```

### Adding a New Module

1. Create `modules/<category>/<name>.nix`
1. Define options under `options.sys.<category>.<name>.*`
1. Implement `config = lib.mkIf cfg.enable { ... };`
1. The module auto-loads—no registration needed

### Related Documentation

- [Architecture Blueprint](../docs/Project_Architecture_Blueprint.md) —
  Full system architecture
- [How to Add Hosts and Users](../docs/how-to-add-host-and-users.md) —
  Practical guide

---

*This documentation was generated with the assistance of LLMs and may require
verification against current implementation.*
