# Project Architecture Blueprint

> **Generated:** January 30, 2026
>
> **Project Type:** NixOS Flake Configuration
>
> **Architecture Pattern:** Modular Auto-Loading with Role-Based Composition

## 1. Executive Summary

This repository implements a modular NixOS configuration system using Nix Flakes. The architecture emphasizes:

- **Auto-loading modules** via recursive file discovery
- **Role-based composition** (desktop/server) with sensible defaults
- **Secrets-driven user management** via an external `nix-secrets` flake
- **Home Manager integration** as a NixOS module with layered configuration

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                              flake.nix                                  │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  mkHost(hostname) → nixpkgs.lib.nixosSystem                      │   │
│  │    • system-loader.nix (auto-imports modules/)                   │   │
│  │    • host-loader.nix (auto-imports hosts/<hostname>/**/*.nix)    │   │
│  │    • home-manager.nixosModules.home-manager                      │   │
│  │    • sops-nix, lanzaboote, microvm                               │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  Outputs: nixosConfigurations.{snowfall,blizzard,avalanche,kaizer}      │
│           nixosConfigurations.{adguard-vm,actual-vm,searx-vm,...}     │
│           (via vms/flake-microvms.nix)                                   │
│           formatter, checks                                             │
└─────────────────────────────────────────────────────────────────────────┘
```

## 2. Architectural Layers

### Layer 1: Flake Entry Point

[flake.nix](../flake.nix) defines:

| Component | Purpose |
|-----------|---------|
| `inputs` | Pinned external dependencies (nixpkgs, home-manager, sops-nix, lanzaboote, microvm, etc.) |
| `mkHost` | Factory function creating NixOS system configurations |
| `nixosConfigurations` | Host outputs for `snowfall`, `blizzard`, `avalanche`, `kaizer` (MicroVMs merged from [vms/flake-microvms.nix](../vms/flake-microvms.nix)) |
| `formatter` | treefmt wrapper for consistent formatting |
| `checks` | Flake validation and formatting checks |

### Layer 2: System Module Loading

[system-loader.nix](../system-loader.nix) auto-imports all `.nix` files under `modules/`:

```nix
imports = lib.filter (n: lib.strings.hasSuffix ".nix" n) (
  lib.filesystem.listFilesRecursive ./modules
);
```

### Layer 3: Home Manager Loading

[hm-loader.nix](../hm-loader.nix) auto-imports `home/` modules, excluding override directories:

```nix
regularModules = lib.filter (
  path: (isNixFile path) && !(isHostOverride path) && !(isUserConfig path)
) paths;
```

### Layer 4: Host Configuration

Each host in `hosts/<hostname>/` provides:

- Hardware configuration
- Host-specific packages
- Role and service enablement
- User enablement toggles

## 3. Component Architecture

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                         SYSTEM CONFIGURATION                            │
├─────────────────────────────────────────────────────────────────────────┤
│  modules/                                                               │
│  ├── core/           ← Core system: users, sops, roles, nix, locale     │
│  ├── boot/           ← Boot: plymouth, secureboot (lanzaboote)          │
│  ├── desktop/        ← Desktop: base + flavors (gnome, kde, hyprland)   │
│  ├── hardware/       ← Hardware: nvidia, etc.                           │
│  ├── networking/     ← Networking: base, networkd, networkmanager       │
│  ├── programs/       ← System programs: gaming, gnupg, ssh, nix-ld      │
│  ├── security/       ← Security: secrets, ssh-hardening                 │
│  ├── services/       ← Services: grafana, tailscale, jellyfin, etc.     │
│  ├── storage/        ← Storage: ZFS, sanoid, NFS                        │
│  └── virtualisation/ ← VMs: microvm integration                         │
│                                                                         │
│  role-desktop.nix    ← Desktop role defaults                            │
│  role-server.nix     ← Server role defaults                             │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         HOME MANAGER CONFIGURATION                      │
├─────────────────────────────────────────────────────────────────────────┤
│  home/                                                                  │
│  ├── base.nix        ← Shared defaults for all users                    │
│  ├── desktop/        ← Desktop: gnome, kde, hyprland, xdg               │
│  ├── files/          ← Managed dotfiles and themes                      │
│  ├── overrides/                                                         │
│  │   ├── host/       ← Per-host HM overrides                            │
│  │   │   └── <hostname>.nix                                             │
│  │   └── user/       ← Per-user@host HM overrides                       │
│  │       └── <user>-<host>.nix                                          │
│  ├── programs/       ← User programs: browsers, terminal, media         │
│  ├── security/       ← User secrets (sops)                              │
│  └── services/       ← User services: gpg-agent, ssh-agent              │
└─────────────────────────────────────────────────────────────────────────┘
```

## 4. Option Namespace Architecture

All custom options use the `sys.*` namespace for system modules and `hm.*` for Home Manager:

### System Options (`sys.*`)

| Namespace | Purpose | Example |
|-----------|---------|---------|
| `sys.role.desktop.enable` | Enable desktop role | `true` |
| `sys.role.server.enable` | Enable server role | `true` |
| `sys.desktop.flavor` | Desktop environment | `"gnome"`, `"kde"`, `"hyprland"` |
| `sys.users.<name>.enable` | Per-host user enablement | `true` |
| `sys.home.enable` | Enable Home Manager integration | `true` |
| `sys.home.template` | Base HM config for all users | `{ }` |
| `sys.home.users.<name>.*` | Per-user HM overrides | `{ extraModules = [...]; }` |
| `sys.services.<name>.*` | Service configurations | `sys.services.grafana.enable` |
| `sys.programs.<name>.*` | Program configurations | `sys.programs.nix-ld.enable` |
| `sys.boot.*` | Boot options | `sys.boot.lanzaboote.enable` |
| `sys.networking.*` | Network options | `sys.networking.networkmanager.enable` |

### Home Manager Options (`hm.*`)

| Namespace | Purpose | Example |
|-----------|---------|---------|
| `hm.desktop.gnome.enable` | GNOME configuration | `true` |
| `hm.desktop.kde.enable` | KDE configuration | `true` |
| `hm.programs.terminal.enable` | Terminal tools | `true` |
| `hm.programs.browsers.enable` | Browser config | `true` |
| `hm.services.gpgAgent.enable` | GPG agent | `true` |

## 5. Data Flow Architecture

### User Configuration Flow

```text
┌──────────────┐     ┌─────────────────────┐     ┌──────────────────────┐
│ nix-secrets  │────▶│ VARS.users          │────▶│ user-options.nix     │
│ (external)   │     │ (role-keyed data)   │     │ sys.users.<name>     │
└──────────────┘     └─────────────────────┘     └──────────────────────┘
                                                          │
       ┌──────────────────────────────────────────────────┘
       ▼
┌──────────────────────┐     ┌─────────────────────────────────────────┐
│ users.nix            │────▶│ NixOS users.users.<name>                │
│ (creates accounts)   │     │ (shell, groups, keys, hashedPassword)   │
└──────────────────────┘     └─────────────────────────────────────────┘
       │
       ▼
┌──────────────────────┐     ┌─────────────────────────────────────────┐
│ home-users.nix       │────▶│ home-manager.users.<name>               │
│ (builds HM configs)  │     │ (imports hm-loader + overrides)         │
└──────────────────────┘     └─────────────────────────────────────────┘
```

### Secrets Flow (sops-nix)

```text
┌──────────────────┐     ┌─────────────────────────────────────────────┐
│ nix-secrets      │────▶│ sops.defaultSopsFile                        │
│ (encrypted)      │     └─────────────────────────────────────────────┘
└──────────────────┘                       │
                                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ modules/core/sops.nix                                                │
│  • Conditional secret definitions based on service enablement        │
│  • whenEnabled hasTailscale { "general/tsKeyFilePath" = { }; }       │
│  • Host-specific secrets (isBlizzard, isSnowfall, etc.)              │
└──────────────────────────────────────────────────────────────────────┘
                                           │
                                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Runtime: /run/secrets/<path>                                         │
│ Consumed by services via config.sops.secrets.<name>.path             │
└──────────────────────────────────────────────────────────────────────┘
```

## 6. Role Architecture

Roles bundle sensible defaults for machine classes:

### Desktop Role ([role-desktop.nix](../modules/role-desktop.nix))

```text
sys.role.desktop.enable = true
    │
    ├── sys.boot.lanzaboote.enable = true
    ├── sys.boot.plymouth.enable = true
    │
    ├── sys.networking.base.enable = true
    ├── sys.networking.networkmanager.enable = true
    │
    ├── sys.programs.gaming.enable = true
    ├── sys.programs.java.enable = true
    ├── sys.programs.ssh.enable = true
    │
    ├── sys.services.openssh.enable = true
    ├── sys.services.pipewire.enable = true
    ├── sys.services.printing.enable = true
    ├── sys.services.flatpak.enable = true
    ├── sys.services.tailscale.enable = true
    │
    ├── sys.virtualisation.enable = true
    │
    └── sys.home.enable = true
```

### Server Role ([role-server.nix](../modules/role-server.nix))

```text
sys.role.server.enable = true
    │
    ├── sys.boot.lanzaboote.enable = true
    ├── sys.boot.plymouth.enable = false
    │
    ├── sys.networking.base.enable = true
    ├── sys.networking.networkd.enable = true
    │
    ├── sys.programs.ssh.enable = true
    │
    ├── sys.services.openssh.enable = true
    ├── sys.services.autoUpgrade.enable = true
    ├── sys.services.tailscale.enable = true
    │
    └── sys.home.enable = true
```

## 7. Desktop Environment Architecture

### System-Level Flavors

[modules/desktop/base.nix](../modules/desktop/base.nix) defines `sys.desktop.flavor`:

```nix
type = lib.types.enum [ "none" "gnome" "kde" "hyprland" "cosmic" ];
```

Each flavor in `modules/desktop/flavors/` configures:

- Display manager (GDM, SDDM)
- Desktop environment packages
- System-level integration

### Home Manager Auto-Enablement

[home-users.nix](../modules/core/home-users.nix) automatically enables HM desktop modules:

```nix
autoDesktopConfig = lib.optionalAttrs (flavor != null && elem flavor ["kde" "gnome" "hyprland"]) {
  hm.desktop.${flavor}.enable = lib.mkDefault true;
};
```

## 8. Service Architecture

Services follow a consistent pattern under `modules/services/`:

```nix
{
  options.sys.services.<name> = {
    enable = lib.mkEnableOption "<service> description";
    port = lib.mkOption { ... };
    openFirewall = lib.mkOption { ... };
    # Service-specific options
  };

  config = lib.mkIf cfg.enable {
    services.<upstream-service> = { ... };
    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ cfg.port ];
  };
}
```

### Available Services

| Service | Module | Purpose |
|---------|--------|---------|
| Grafana | `grafana.nix` | Visualization and dashboarding |
| Prometheus | `prometheus.nix` | Metrics collection |
| VictoriaMetrics | `victoriametrics.nix` | Time-series database |
| Tailscale | `tailscale.nix` | Mesh VPN |
| Jellyfin | `jellyfin.nix` | Media server |
| Immich | `immich.nix` | Photo management |
| Traefik | `traefik.nix` | Reverse proxy |
| Cloudflared | `cloudflared.nix` | Tunnel to Cloudflare |
| CrowdSec | `crowdsec.nix` | Security automation |
| Gitea | `gitea.nix` | Git hosting |
| AdGuard Home | `adguardhome.nix` | DNS filtering |
| Paperless-ngx | `paperless.nix` | Document management |
| Firefly III | `firefly.nix` | Personal finance manager |
| Grafana Pushover | `grafana-pushover.nix` | Pushover alert notifications |

## 9. MicroVM Architecture

The flake supports MicroVMs for isolated services:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│  Host (blizzard)                                                        │
│  ├── microvm.nixosModules.host                                          │
│  └── sys.virtualisation.microvm.*                                       │
└─────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  vms/base.nix                                                           │
│  ├── Standard kernel (linuxPackages) + sysctl hardening                │
│  ├── Kernel security sysctl settings                                    │
│  ├── Minimal attack surface                                             │
│  └── Restricted services                                                │
└─────────────────────────────────────────────────────────────────────────┘
         │
         ├── vms/actual.nix (Actual Budget VM)
         ├── vms/adguard.nix (AdGuard Home VM)
         ├── vms/firefox.nix, brave.nix (Browser VMs)
         ├── vms/firefly.nix (Firefly III VM)
         ├── vms/gitea.nix (Gitea VM)
         ├── vms/matrix-synapse.nix (Matrix Synapse VM)
         ├── vms/ombi.nix (Ombi VM)
         ├── vms/overseerr.nix (Overseerr VM)
         ├── vms/paperless.nix (Paperless-ngx VM)
         ├── vms/qbittorrent.nix, sabnzbd.nix
         ├── vms/searx.nix (SearXNG VM)
         ├── vms/sonarr.nix, radarr.nix, prowlarr.nix, bazarr.nix, ...
         ├── vms/tautulli.nix (Tautulli VM)
         └── vms/wireguard.nix (WireGuard VM)
```

MicroVMs do **not** use `system-loader.nix` to avoid importing host-only modules.
Their outputs are defined in [vms/flake-microvms.nix](../vms/flake-microvms.nix) and merged into
`nixosConfigurations` in [flake.nix](../flake.nix).

## 10. Library Architecture

Custom library functions in `lib/`:

### Grafana Dashboards ([lib/grafana-dashboards.nix](../lib/grafana-dashboards.nix))

```nix
{
  fetchGrafanaDashboard = { gnetId, revision, hash, name ? ... }: ...;

  community = {
    node-exporter-full = fetchGrafanaDashboard { gnetId = 1860; ... };
    kubernetes-cluster = fetchGrafanaDashboard { gnetId = 315; ... };
  };

  custom = {
    zfs-overview = ../dashboards/host/blizzard/zfs-overview.json;
    power-consumption = ../dashboards/shared/power-consumption.json;
  };

  all = community // custom;
}
```

## 11. Host Configuration Reference

| Host | Role | Desktop | Key Services |
|------|------|---------|--------------|
| `snowfall` | Desktop | KDE | Distributed builds client |
| `blizzard` | Server | None | Grafana, NFS, Samba, Tailscale router |
| `avalanche` | Desktop | GNOME | Secondary workstation |
| `kaizer` | Desktop | KDE | External access |

### Host Configuration Pattern

All `.nix` files under a host directory are auto-imported by
[host-loader.nix](../host-loader.nix). No explicit `imports` needed for local
files:

```nix
# hosts/<hostname>/<hostname>.nix
{
  networking = {
    hostName = lib.mkForce "<hostname>";
    hostId = lib.mkForce "<unique-id>";
  };

  sys = {
    role.server.enable = true;  # or role.desktop.enable
    users.zeno.enable = true;

    services = {
      tailscale.enable = true;
    };
  };
}
```

## 12. Extension Patterns

### Adding a New System Module

1. Create `modules/<category>/<name>.nix`
1. Define options under `options.sys.<category>.<name>.*`
1. Implement `config = lib.mkIf cfg.enable { ... };`
1. Module auto-imports via `system-loader.nix`

### Adding a New Home Manager Module

1. Create `home/<category>/<name>.nix`
1. Define options under `options.hm.<category>.<name>.*`
1. Implement `config = lib.mkIf cfg.enable { ... };`
1. Module auto-imports via `hm-loader.nix`

### Adding a New Host

1. Create `hosts/<hostname>/` directory
1. Add `hardware-configuration.nix` (from `nixos-generate-config`)
1. Add `packages.nix` for host-specific packages
1. Add `<hostname>.nix` with role, users, and services
1. Register in `flake.nix`: `<hostname> = mkHost "<hostname>" [ ];`

### Adding a New User

1. Add user to `nix-secrets` (VARS.users)
1. Enable per-host: `sys.users.<username>.enable = true;`
1. Optionally add `home/overrides/user/<user>-<host>.nix`

### Adding Host-Wide HM Overrides

1. Create `home/overrides/host/<hostname>.nix`
1. Configure HM options that apply to all users on that host

## 13. Dependency Graph

```text
                    ┌─────────────┐
                    │   flake.nix │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
┌─────────────────┐ ┌─────────────┐ ┌─────────────────┐
│ system-loader   │ │ host config │ │ external inputs │
│ (modules/*)     │ │ (hosts/*)   │ │ (HM, sops, etc.)│
└────────┬────────┘ └──────┬──────┘ └────────┬────────┘
         │                 │                 │
         └────────────────►│◄────────────────┘
                           ▼
                 ┌─────────────────┐
                 │ NixOS System    │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ Home Manager    │
                 │ (hm-loader.nix) │
                 └─────────────────┘
```

## 14. Configuration Precedence

Options merge with the following precedence (lowest to highest):

1. **Module defaults** (`lib.mkDefault`)
1. **Role defaults** (role-desktop.nix, role-server.nix)
1. **Base HM template** (`sys.home.template`)
1. **Auto desktop config** (hm.desktop.\<flavor>.enable)
1. **Host overrides** (`home/overrides/host/<hostname>.nix`)
1. **User-specific overrides** (`home/overrides/user/<user>-<host>.nix`)
1. **Per-user extraConfig** (`sys.home.users.<name>.extraConfig`)
1. **Host configuration** (`hosts/<hostname>/<hostname>.nix`)
1. **Force overrides** (`lib.mkForce`)

## 15. Testing and Validation

### Flake Checks

```bash
nix flake check              # Full validation
nix flake check --no-build   # Fast validation without building
nix flake check --show-trace # Debug failures
```

### Formatting

```bash
nix fmt  # Format all Nix files via treefmt
```

### Building

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

### Switching

```bash
sudo nixos-rebuild switch --flake .#<hostname>
sudo nixos-rebuild test --flake .        # Test without switching
nixos-rebuild dry-run --flake .          # Show what would change
```

## 16. Security Architecture

### Secrets Management

- **sops-nix** decrypts secrets at activation time
- Age encryption using SSH host keys (`/etc/ssh/ssh_host_ed25519_key`)
- Secrets only defined when services are enabled (conditional loading)
- Sensitive data stored in external `nix-secrets` repository

### Secure Boot

- **Lanzaboote** for UEFI Secure Boot
- Enabled by default in both desktop and server roles
- Configured via `sys.boot.lanzaboote.enable`

### MicroVM Hardening

- Runtime kernel hardening (`linuxPackages` with sysctl hardening)
- Restrictive sysctl settings
- Disabled unnecessary services
- Blacklisted kernel modules (bluetooth, uvcvideo)

## 17. Maintenance Recommendations

### Keeping the Blueprint Current

- Update this document when adding new architectural components
- Review after significant refactoring
- Validate option namespaces remain consistent

### Recommended Practices

- **Use roles** for common machine configurations
- **Prefer `lib.mkDefault`** for overridable defaults
- **Keep secrets external** in `nix-secrets`
- **Test with `nix flake check`** before committing
- **Document service dependencies** in module comments

______________________________________________________________________

*This blueprint reflects the architecture as of January 30, 2026. Review and update as the configuration evolves.*
