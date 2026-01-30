## Host Configurations

Per-machine NixOS configurations defining hardware, roles, users, and services.

### Hosts Overview

| Host | Role | Desktop | Description |
|------|------|---------|-------------|
| [snowfall/](snowfall/) | Desktop | KDE | Primary workstation, distributed builds client |
| [blizzard/](blizzard/) | Server | None | Home server: Grafana, NFS, Samba, Tailscale router |
| [avalanche/](avalanche/) | Desktop | — | Secondary workstation |
| [kaizer/](kaizer/) | — | — | External access machine |

### Host Structure

Each host directory contains:

```
hosts/<hostname>/
├── <hostname>.nix           # Main configuration
├── hardware-configuration.nix  # Hardware-specific (from nixos-generate-config)
└── packages.nix             # Host-specific packages
```

### Configuration Pattern

```nix
# hosts/<hostname>/<hostname>.nix
{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ];

  networking = {
    hostName = lib.mkForce "<hostname>";
    hostId = lib.mkForce "<unique-8-char-hex>";
  };

  sys = {
    # Choose a role
    role.desktop.enable = true;  # or role.server.enable

    # Select desktop flavor (for desktop role)
    desktop.flavor = "kde";  # or "gnome", "hyprland", "cosmic"

    # Enable users for this host
    users.zeno.enable = true;

    # Configure services
    services = {
      tailscale.enable = true;
      grafana.enable = true;
    };
  };
}
```

### Adding a New Host

1. Create directory: `hosts/<hostname>/`

2. Generate hardware config:
   ```bash
   nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix
   ```

3. Create `packages.nix` for host-specific packages:
   ```nix
   { pkgs, ... }: {
     environment.systemPackages = with pkgs; [
       # Host-specific packages
     ];
   }
   ```

4. Create `<hostname>.nix` with role and user configuration

5. Register in [flake.nix](../flake.nix):
   ```nix
   nixosConfigurations = {
     <hostname> = mkHost "<hostname>" [ ];
   };
   ```

6. Build and switch:
   ```bash
   sudo nixos-rebuild switch --flake .#<hostname>
   ```

### Host ID Generation

Generate a unique 8-character hex ID for ZFS:

```bash
head -c 4 /dev/urandom | od -A none -t x4 | tr -d ' '
```

### Related Documentation

- [Tutorial: Provision a Host](../docs/tutorial-provision-host.md)
- [How to Add Hosts and Users](../docs/how-to-add-host-and-users.md)
- [Role Desktop](../modules/role-desktop.nix) — Desktop role defaults
- [Role Server](../modules/role-server.nix) — Server role defaults
