## Host Configurations

Per-machine NixOS configurations defining hardware, roles, users, and services.

### Hosts Overview

| Host | Role | Desktop | Standout Features |
|------|------|---------|------------------|
| [snowfall/](snowfall/) | Desktop | KDE | AMD GPU, remote builder paused, openrazer (RGB), Prometheus+Grafana+Traefik+Cloudflare tunnel, RAPL + electricity-price exporters |
| [blizzard/](blizzard/) | Server | None | ZFS+NFS+Samba, full observability stack, MicroVM host, Tailscale subnet router (192.168.2.0/24 + 10.100.0.0/24), CrowdSec, VictoriaMetrics |
| [avalanche/](avalanche/) | Desktop | GNOME | ThinkPad P51, nixos-hardware module, iwlwifi+BT coexistence workaround, VictoriaMetrics remote-write to blizzard |
| [kaizer/](kaizer/) | Desktop | KDE | Two users (gianluca+luke; frankie disabled), Lanzaboote disabled, CachyOS kernel, NVIDIA GPU (open kernel modules), Java Temurin 8/17/21 for Minecraft, per-user localization |

Snowfall and Blizzard enable dedicated Sandfly OpenSSH listeners on their
Tailscale IPv4 addresses at TCP 2222. Review
[the Sandfly operations prerequisite](../docs/sandfly.md#policy-prerequisite)
before activating these configurations; human Tailscale SSH must deny the
privileged scanner account.

### CachyOS kernel cache

Snowfall and Kaizer use [Chaotic-Nyx](https://www.nyx.chaotic.cx/)'s
`nyxpkgs-unstable` input, `nyx-cache` and `nyx-overlay` modules, and
`pkgs.linuxPackages_cachyos`. Kaizer selects `pkgs.nvidia_cachyos` through
`sys.hardware.nvidia.package` and keeps `sys.hardware.nvidia.open = true` to
use its matching open kernel modules. Both hosts also enable OpenRazer.

The `nyx-cache` module defaults `chaotic.nyx.cache.enable` to `true`, adding
Nyx's substituter and signing key to `nix.settings`. These settings take effect
in the running daemon after activating the host configuration.

Keep Nyx's own dependency pins: making its `nixpkgs` input follow this
repository's input, or customizing its kernel build, can change store hashes
and require compilation. The previous upstream Attic cache is not used. Its former endpoint and signing authority remain incident-disabled; reintroducing them requires a separately reviewed replacement and provenance check.

Before the new cache configuration is activated, pass its settings explicitly.
This downloads the kernel outputs and external modules, refusing compilation
if a required binary is missing:

```bash
nix build --no-link --max-jobs 0 --builders '' \
  --option extra-substituters https://nyx-cache.chaotic.cx/ \
  --option extra-trusted-public-keys 'nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=' \
  '.#nixosConfigurations.snowfall.config.boot.kernelPackages.kernel^*' \
  '.#nixosConfigurations.kaizer.config.boot.kernelPackages.kernel^*' \
  '.#nixosConfigurations.kaizer.config.hardware.nvidia.package.open' \
  '.#nixosConfigurations.snowfall.config.boot.kernelPackages.openrazer' \
  '.#nixosConfigurations.kaizer.config.boot.kernelPackages.openrazer'
```

This command needs the private `nix-secrets` input for host evaluation; see
[the CI reference](../docs/reference-ci.md#introduction). It does not
activate a configuration or persist the command-line cache settings. The first
deployment also needs these explicit cache options; later rebuilds use the
Nyx settings installed by that deployment. Inspect `nix config show substituters`
and `/etc/nix/nix.conf` on the host when checking active daemon settings.

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

`packages.nix` adds system-wide packages only for that host. Packages shared by
a role belong in `modules/role-<role>.nix`. To add Home Manager packages for
every managed user on a host, use `home/overrides/host/<hostname>.nix` instead.
The [package placement table](../home/README.md#package-placement) lists every
scope; all these native package lists combine.

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
- [Immich Backup Operations](../docs/immich-backup.md)
- [Matrix Backup Operations](../docs/matrix-backup.md)
- [Role Desktop](../modules/role-desktop.nix) — Desktop role defaults
- [Role Server](../modules/role-server.nix) — Server role defaults
