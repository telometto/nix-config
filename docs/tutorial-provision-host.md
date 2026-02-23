# Tutorial: Provision a New Host

Goal: Bring a new machine under this repo, with auto-loaded system and Home Manager modules, a desktop flavor (optional), and enabled users from `VARS`.

## Prerequisites

- NixOS installed on the target machine.
- Access to this repo and the private secrets repo providing `VARS`.

## Steps

1. Clone the repo on the target machine:

```bash
git clone https://github.com/yourusername/nix-config.git
cd nix-config
```

2. Create a host directory or reuse one under `hosts/`:

- Copy an existing host (e.g., `hosts/avalanche/`) as a template, or create a new `<hostname>/` with:
  - `<hostname>.nix`
  - `hardware-configuration.nix` (from `nixos-generate-config`)
  - `packages.nix` (optional per-host packages)

3. Define basics in `<hostname>.nix`:

```nix
{ lib, ... }:
{
  networking.hostName = lib.mkForce "<hostname>";

  sys.role.desktop.enable = true;      # or server
  sys.desktop.flavor = "gnome";       # kde | gnome | hyprland | omit for servers

  sys.users.zeno.enable = true;
}
```

All `.nix` files in the host directory (including `hardware-configuration.nix`
and `packages.nix`) are auto-imported by
[host-loader.nix](../host-loader.nix) — no explicit `imports` needed for local
files.

4. Switch to the configuration:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

This builds the system with all modules auto-imported and sets up Home Manager for enabled users.

## Optional: Home Manager Overrides

- Host-wide HM overrides: `home/overrides/host/<hostname>.nix`.
- User@host HM overrides: `home/overrides/user/<user>-<hostname>.nix`.

These are automatically included via the HM integration logic.

## Verify

- Desktop flavor applies (if enabled): KDE/GNOME/Hyprland HM bits auto-enable.
- Users exist and can login; HM profiles are active.
- Services enabled via `sys.services.*` run as expected.

You've provisioned a host. Continue with service enablement and secrets as
needed.

______________________________________________________________________

*This documentation was generated with the assistance of LLMs and may require
verification against current implementation.*
