## NixOS Configuration

Modular NixOS flake with automatic module loading for multiple hosts.

## Quick Start

```bash
git clone --depth=1 https://github.com/telometto/nix-config.git
cd nix-config
sudo nixos-rebuild switch --flake .#<hostname>
```

## Features

- **Auto-loaded modules** — Drop files in [modules/](modules/) or [home/](home/)
  and they're automatically imported
- **Role-based defaults** — Enable `sys.role.desktop` or `sys.role.server` for
  sensible defaults
- **Per-host toggles** — Enable users and services per machine with `sys.*`
  options

## Repository Structure

| Directory | Purpose |
|-----------|---------|
| [modules/](modules/) | System modules (`sys.*` options) |
| [home/](home/) | Home Manager modules (`hm.*` options) |
| [hosts/](hosts/) | Host configurations |
| [vms/](vms/) | MicroVM definitions |
| [docs/](docs/) | Documentation |

## Host Configuration

```nix
# hosts/<hostname>/<hostname>.nix
{
  sys.role.desktop.enable = true;      # or sys.role.server.enable
  sys.desktop.flavor = "kde";          # gnome, kde, hyprland
  sys.users.zeno.enable = true;        # enable users per host
  sys.services.tailscale.enable = true;
}
```

## Common Commands

| Command | Description |
|---------|-------------|
| `sudo nixos-rebuild switch --flake .#<host>` | Apply configuration |
| `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` | Build only |
| `nix fmt` | Format repository |
| `nix flake check` | Run checks |

## Hosts

| Host | Role | Desktop |
|------|------|---------|
| snowfall | Desktop | KDE |
| blizzard | Server | — |
| avalanche | Desktop | — |
| kaizer | — | — |

## Documentation

| Document | Description |
|----------|-------------|
| [Tutorial: Provision Host](docs/tutorial-provision-host.md) | Set up a new machine |
| [How-To: Add Hosts and Users](docs/how-to-add-host-and-users.md) | Add new hosts/users |
| [Reference: Architecture](docs/reference-architecture.md) | Options quick reference |
| [Explanation: Design](docs/explanation-design.md) | Design decisions |
| [Architecture Blueprint](docs/Project_Architecture_Blueprint.md) | Full system design |

See [docs/README.md](docs/README.md) for the complete documentation index.

---

*This documentation was generated with the assistance of LLMs and may require
verification against current implementation.*
