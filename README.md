# ❄️ NixOS Configuration

A declarative, reproducible NixOS configuration for multiple hosts using flakes, home-manager, and automated maintenance.

## 📚 Overview

This repository contains my personal NixOS configuration for managing multiple machines with a unified, declarative approach. It leverages Nix flakes for reproducibility, home-manager for user environment management, and includes automated formatting and compliance checking via GitHub Actions.

### ✨ Features

- **Multi-host support** - Configurations for `snowfall`, `blizzard`, and `avalanche` hosts
- **Modular architecture** - Reusable modules for common configurations
- **Home Manager integration** - Declarative user environment management
- **Automated formatting** - Uses `treefmt-nix` for consistent code style across Nix, Shell, YAML, and Markdown files
- **CI/CD Pipeline** - GitHub Actions for validation, compliance checking, and automatic updates
- **Security-first** - Automated checks for hardcoded secrets and security patterns

## 🏗️ Structure

```
.
├── flake.nix           # Entry point - defines inputs and outputs
├── flake.lock          # Locked dependencies for reproducibility
├── treefmt.nix         # Multi-language formatter configuration
├── hosts/              # Host-specific configurations
│   ├── avalanche/      # Desktop configuration
│   ├── blizzard/       # Server configuration
│   └── snowfall/       # Laptop configuration
├── modules/            # Reusable NixOS modules
│   ├── core/           # Core system modules (locale, networking, etc.)
│   ├── desktop/        # Desktop environment modules
│   ├── hardware/       # Hardware-specific modules
│   └── services/       # Service configurations
├── home/               # Home Manager configurations
│   └── users/          # Per-user home configurations
└── .github/            # CI/CD workflows
    └── workflows/      # GitHub Actions automation
```

## 🚀 Quick Start

### Prerequisites

- NixOS installed on your system
- Git for cloning the repository
- (Optional) SSH keys configured for GitHub access

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/yourusername/nix-config.git
cd nix-config
```

2. **Build a specific host configuration:**
```bash
# Build the snowfall (laptop) configuration
nix build .#nixosConfigurations.snowfall.config.system.build.toplevel

# Build the avalanche (desktop) configuration  
nix build .#nixosConfigurations.avalanche.config.system.build.toplevel
```

3. **Switch to a configuration:**
```bash
# Apply the configuration (requires root)
nixos-rebuild boot .# --sudo
```

## 💻 Usage Examples

### Adding a New Package

To add a package system-wide, edit the relevant host configuration:

```nix
# hosts/snowfall/snowfall.nix
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    firefox
    vscode
    # Add your package here
    neovim
  ];
}
```

### Configuring User Environment

User-specific configurations are managed through Home Manager:

```nix
# home/users/youruser/default.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    git
    tmux
    ripgrep
  ];
  
  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "your.email@example.com";
  };
}
```

### Creating a New Module

Modules provide reusable configuration:

```nix
# modules/services/my-service.nix
{ config, lib, pkgs, ... }:
with lib;
{
  options.services.myService = {
    enable = mkEnableOption "My custom service";
    
    port = mkOption {
      type = types.int;
      default = 8080;
      description = "Port to run the service on";
    };
  };
  
  config = mkIf config.services.myService.enable {
    # Service configuration here
  };
}
```

## 🔧 Development

### Formatting Code

This project uses `treefmt-nix` for consistent formatting:

```bash
# Format all files
nix fmt

# Check formatting without changes
nix fmt -- --check
```

### Running Compliance Checks

Check for code quality and security issues:

```bash
# Run full validation suite
nix flake check

# Build and test a specific host
nix build .#nixosConfigurations.snowfall.config.system.build.toplevel --dry-run
```

## 🤖 Automation

### GitHub Actions Workflows

- **`validate-config.yml`** - Validates syntax and builds configurations on every PR
- **`auto-format.yml`** - Automatically formats code on commits and PRs
- **`compliance-check.yml`** - Weekly security and quality checks
- **`update-nix-lock.yml`** - Automated flake.lock updates

### Manual Workflow Triggers

Most workflows can be triggered manually:

```bash
# Via GitHub CLI
gh workflow run compliance-check.yml

# Or through GitHub web UI
# Navigate to Actions → Select workflow → Run workflow
```

## 📋 Host Configurations

### snowfall (Laptop)
- **Purpose**: Daily driver laptop
- **Features**: Power management, WiFi, Bluetooth
- **Display**: Configured for mobility

### blizzard (Server)
- **Purpose**: Home server / NAS
- **Features**: Container hosting, file sharing
- **Services**: Media server, backups

### avalanche (Desktop)
- **Purpose**: Main workstation
- **Features**: Development environment
- **Display**: Multi-monitor support

## 🛡️ Security

- Secrets are managed separately and not committed to the repository
- Automated checks prevent hardcoded passwords
- Regular dependency updates via automated flake.lock updates
- Compliance checking ensures security best practices

## 📝 Contributing

While this is a personal configuration, suggestions and improvements are welcome:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure `nix fmt` and `nix flake check` pass
5. Submit a pull request

## 📜 License

This configuration is provided as-is for reference and learning purposes. Feel free to use any parts that are helpful for your own configuration.

## 🙏 Acknowledgments

- [NixOS Community](https://nixos.org/) for the amazing ecosystem
- [home-manager](https://github.com/nix-community/home-manager) for user environment management
- [treefmt-nix](https://github.com/numtide/treefmt-nix) for unified formatting
- All the Nix package maintainers who make this possible

---

*Configuration tested on NixOS 24.05*