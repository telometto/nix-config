# NixOS Configurations (Flakes + Auto-Loaded Modules)

Welcome. This repo provides a modular NixOS setup for multiple hosts with automatic system and Home Manager module loading. Newcomers can onboard quickly: define a host, toggle roles and users, and switch.

## What You Get

- Multi-host flake outputs for `snowfall`, `blizzard`, `avalanche`, `kaizer`.
- Auto-loaded system modules via [system-loader.nix](system-loader.nix).
- Auto-loaded Home Manager modules via [hm-loader.nix](hm-loader.nix) integrated as a NixOS module.
- Opt-in roles and services (enable via `sys.*` options).
- Per-host user enable/disable sourced from secrets (`VARS`) with Home Manager profiles built automatically.

## Repo Layout

```
.
├── flake.nix                 # Flake inputs/outputs; defines hosts via mkHost
├── system-loader.nix         # Auto-imports all .nix under modules/
├── hm-loader.nix             # Auto-imports home/ modules (excludes overrides)
├── modules/                  # System modules and options (auto-loaded)
│   ├── core/                 # Core: roles, users, home integration, sops, etc.
│   ├── desktop/              # Desktop base + flavors
│   ├── hardware/             # Hardware helpers (e.g., nvidia)
│   └── services/             # Services (grafana, jellyfin, tailscale, ...)
├── home/                     # Home Manager modules (auto-loaded)
│   ├── programs/             # HM program configs
│   ├── desktop/              # HM desktop integrations
│   └── users/                # Overrides per host/user (opt-in)
│       ├── host-overrides/   # Applied to all HM users on a host
│       └── user-configs/     # Applied to a specific user@host
└── hosts/                    # Host definitions (avalanche, blizzard, snowfall, kaizer)
```

## Onboarding Tutorial (New Machine)

1) Install NixOS and clone this repo:

```bash
git clone https://github.com/yourusername/nix-config.git
cd nix-config
```

2) Pick or create a host under [hosts/](hosts). Example: [hosts/avalanche/avalanche.nix](hosts/avalanche/avalanche.nix)

- Set hostname and bring in hardware and packages files.
- Toggle a role and desktop flavor:

```nix
sys.role.desktop.enable = true;
sys.desktop.flavor = "gnome"; # or "kde", "hyprland"
```

3) Enable users for this host (from secrets `VARS`):

```nix
# Per-host user switches (defined for each user found in VARS)
sys.users.zeno.enable = true;
```

4) Switch to the host configuration:

```bash
sudo nixos-rebuild switch --flake .#avalanche
```

That’s it. System modules are auto-imported; HM profiles are generated and applied for enabled users.

## How It Works

- System modules: [system-loader.nix](system-loader.nix) imports every `.nix` under [modules/](modules). Modules expose options (e.g., `sys.services.grafana.enable`) you can toggle in a host file.

- Home Manager integration: `inputs.home-manager.nixosModules.home-manager` is included in the system. The HM layer is orchestrated by:
  - [modules/core/home-options.nix](modules/core/home-options.nix): `sys.home.enable` and per-user knobs.
  - [modules/core/home-users.nix](modules/core/home-users.nix): Builds HM configs for enabled users from `VARS`, auto-imports [hm-loader.nix](hm-loader.nix), host/user overrides, and desktop flavor defaults.
  - [hm-loader.nix](hm-loader.nix): imports all `.nix` under [home/](home), excluding [home/users/host-overrides/](home/users/host-overrides) and [home/users/user-configs/](home/users/user-configs).

- Users and secrets: Users come from `VARS` (provided by your private secrets flake). Per-host enable toggles live under `sys.users.<username>.enable` via [modules/core/user-options.nix](modules/core/user-options.nix). Accounts are created by [modules/core/users.nix](modules/core/users.nix).

- Secrets with sops-nix: [modules/core/sops.nix](modules/core/sops.nix) wires secrets and templates. Secrets for services are defined only when those services are enabled.

## Opt-in Toggles (Examples)

Enable desktop role and HM:

```nix
sys.role.desktop.enable = true;
sys.home.enable = true; # defaults to true when roles enable HM
```

Turn on services:

```nix
sys.services.grafana.enable = true;
sys.services.prometheus.enable = true;
sys.services.tailscale = { enable = true; interface = "wlp4s0"; };
```

Opt-in programs:

```nix
sys.programs.python-venv.enable = true;
sys.programs.nix-ld.enable = true;
```

Per-host HM overrides:

- Put shared-for-host HM settings in [home/users/host-overrides/<hostname>.nix](home/users/host-overrides).
- Put user@host specific HM settings in [home/users/user-configs/<user>-<hostname>.nix](home/users/user-configs).

## Commands

- Build a host:

```bash
nix build .#nixosConfigurations.snowfall.config.system.build.toplevel
```

- Switch to a host configuration:

```bash
sudo nixos-rebuild switch --flake .#snowfall
```

- Format the repo:

```bash
nix fmt
```

- Run flake checks:

```bash
nix flake check
```

## Reference & Further Reading
- **NOTE:** Documentation has been generated using LLM
- [Flake: `flake.nix`](flake.nix)
- [System loader](system-loader.nix), [Home loader](hm-loader.nix)
- Core: [roles](modules/core/roles.nix), [home options](modules/core/home-options.nix), [home users](modules/core/home-users.nix), [user options](modules/core/user-options.nix), [users](modules/core/users.nix), [sops](modules/core/sops.nix)
- Hosts: [hosts/](hosts)

Diátaxis docs for onboarding:
- Tutorial: [docs/tutorial-provision-host.md](docs/tutorial-provision-host.md)
- How-to: [docs/how-to-add-host-and-users.md](docs/how-to-add-host-and-users.md)
- Reference: [docs/reference-architecture.md](docs/reference-architecture.md)
- Explanation: [docs/explanation-design.md](docs/explanation-design.md)

