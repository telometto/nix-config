## Host Configurations

Per-machine NixOS configurations defining hardware, roles, users, and services.

### Hosts Overview

| Host | Role | Desktop | Standout Features |
|------|------|---------|------------------|
| [snowfall/](snowfall/) | Desktop | KDE | AMD GPU, distributed builds server, openrazer (RGB), Prometheus+Grafana+Traefik+Cloudflare tunnel, RAPL + electricity-price exporters |
| [blizzard/](blizzard/) | Server | None | ZFS+NFS+Samba, full observability stack, 24 MicroVM host, Tailscale subnet router (192.168.2.0/24 + 10.100.0.0/24), CrowdSec, k3s, VictoriaMetrics |
| [avalanche/](avalanche/) | Desktop | GNOME | ThinkPad P51, nixos-hardware module, iwlwifi+BT coexistence workaround, VictoriaMetrics remote-write to blizzard |
| [kaizer/](kaizer/) | Desktop | KDE | Two users (gianluca+frankie), Lanzaboote disabled, NVIDIA GPU (legacy open=false), Java Temurin 8/17/21 for Minecraft, Italian locale |

### Host Structure

Each host directory contains:

```
hosts/<hostname>/
├── <hostname>.nix              # Main configuration (imports + core settings)
├── hardware-configuration.nix  # Hardware-specific (from nixos-generate-config)
├── packages.nix                # Host-specific packages
└── [optional subdirectories]   # Domain-specific configs (for complex hosts)
```

For complex hosts like servers, configuration is organized into subdirectories:

```
hosts/blizzard/
├── blizzard.nix            # Main: networking, role, users, Tailscale subnet routing
├── hardware-configuration.nix
├── packages.nix
├── boot.nix                # ZFS kernel, sysctl hardening
├── networking.nix          # systemd-networkd static config
├── monitoring/             # Observability stack
│   ├── prometheus.nix
│   ├── grafana.nix
│   ├── victoriametrics.nix
│   └── exporters.nix       # node, ZFS, power, arr, electricity-price exporters
├── storage/                # Storage services
│   ├── zfs.nix
│   ├── nfs.nix
│   └── samba.nix
├── security/               # Security infrastructure
│   ├── crowdsec.nix
│   └── traefik.nix
├── services/               # Application services
│   ├── backup.nix
│   ├── cloudflared.nix
│   ├── media.nix
│   ├── productivity.nix
│   ├── seaweedfs.nix
│   └── system.nix
└── virtualisation/         # VMs and containers
    ├── microvms.nix
    └── containers.nix
```

All `.nix` files are auto-imported recursively by [host-loader.nix](../host-loader.nix) — no explicit
`imports` list needed for local files. External modules (e.g. `nixos-hardware`) still
require an `imports` block.

### Configuration Pattern

All `.nix` files under `hosts/<hostname>/` are auto-imported by
[host-loader.nix](../host-loader.nix). The main `<hostname>.nix` only needs to
set host-specific configuration — no imports block for local files:

```nix
# hosts/<hostname>/<hostname>.nix
{
  networking = {
    hostName = lib.mkForce "<hostname>";
    hostId = lib.mkForce "<unique-8-char-hex>";
  };

  sys = {
    role.desktop.enable = true;  # or role.server.enable

    desktop.flavor = "kde";  # or "gnome", "hyprland", "cosmic"

    users.zeno.enable = true;

    services = {
      tailscale.enable = true;
      grafana.enable = true;
    };
  };
}
```

External modules (e.g. `nixos-hardware`) still require an `imports` block:

```nix
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p51
  ];

  # ... rest of config
}
```

### Adding a New Host

1. Create directory: `hosts/<hostname>/`

1. Generate hardware config:

   ```bash
   nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix
   ```

1. Create `packages.nix` for host-specific packages:

   ```nix
   { pkgs, ... }: {
     environment.systemPackages = with pkgs; [
       # Host-specific packages
     ];
   }
   ```

1. Create `<hostname>.nix` with role and user configuration

1. Register in [flake.nix](../flake.nix):

   ```nix
   nixosConfigurations = {
     <hostname> = mkHost "<hostname>" [ ];
   };
   ```

1. Build and switch:

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
