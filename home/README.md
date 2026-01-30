## Home Manager Modules

Auto-loaded Home Manager modules providing user-level configuration via the
`hm.*` option namespace.

### How It Works

All `.nix` files in this directory (except overrides) are automatically
imported by [hm-loader.nix](../hm-loader.nix). Home Manager is integrated as a
NixOS module, building user configurations automatically for enabled users.

### Directory Structure

| Directory | Purpose | Example Options |
|-----------|---------|-----------------|
| [desktop/](desktop/) | Desktop environment integration | `hm.desktop.gnome.enable`, `hm.desktop.kde.enable` |
| [files/](files/) | Managed dotfiles and themes | File management, Vesktop themes |
| [programs/](programs/) | User applications | `hm.programs.terminal.enable`, `hm.programs.browsers.enable` |
| [security/](security/) | User secrets (sops) | `hm.security.sops.*` |
| [services/](services/) | User services | `hm.services.gpgAgent.enable` |
| [overrides/](overrides/) | Per-host and per-user overrides | Host-specific and user-specific configs |

### Base Configuration

[base.nix](base.nix) provides shared defaults for all users:

- Home Manager state version
- Common program settings
- Default enabled modules

### Desktop Auto-Enablement

When a host sets `sys.desktop.flavor`, the corresponding HM desktop module is
automatically enabled:

```nix
# In host config:
sys.desktop.flavor = "kde";

# Automatically enables:
hm.desktop.kde.enable = true;
```

### Override System

#### Host Overrides

Apply settings to all users on a specific host:

```
home/overrides/host/<hostname>.nix
```

#### User Overrides

Apply settings to a specific user on a specific host:

```
home/overrides/user/<username>-<hostname>.nix
```

### Module Pattern

```nix
{ lib, config, ... }:
let
  cfg = config.hm.<category>.<name>;
in
{
  options.hm.<category>.<name> = {
    enable = lib.mkEnableOption "Feature description";
  };

  config = lib.mkIf cfg.enable {
    # Home Manager configuration
    programs.<program>.enable = true;
  };
}
```

### Adding a New Module

1. Create `home/<category>/<name>.nix`
2. Define options under `options.hm.<category>.<name>.*`
3. Implement `config = lib.mkIf cfg.enable { ... };`
4. Module auto-loads via `hm-loader.nix`

### Configuration Precedence (Low → High)

1. Module defaults (`lib.mkDefault`)
2. Base HM template (`sys.home.template`)
3. Auto desktop config
4. Host overrides (`overrides/host/<hostname>.nix`)
5. User overrides (`overrides/user/<user>-<host>.nix`)
6. Per-user extraConfig (`sys.home.users.<name>.extraConfig`)

### Related Documentation

- [Home users module](../modules/core/home-users.nix) — Builds HM configs
- [Home options module](../modules/core/home-options.nix) —
  `sys.home.*` options
- [Architecture Blueprint](../docs/Project_Architecture_Blueprint.md)
