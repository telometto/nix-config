# Tutorial: Provision a New Host

Goal: Bring a new machine under this repo, with auto-loaded system and Home Manager modules, a desktop flavor (optional), and enabled users from `VARS`.

## Provisioning Flow

```mermaid
sequenceDiagram
    participant M as Target Machine
    participant R as Repo
    participant S as nix-secrets

    M->>R: git clone
    M->>M: nixos-generate-config (hardware-configuration.nix)
    R->>R: create hosts/<hostname>/
    R->>R: register in flake.nix
    M->>S: configure SOPS age key
    M->>M: nixos-rebuild switch --flake .#<hostname>
    M-->>M: system built, users created, HM active
```

## Prerequisites

- NixOS installed on the target machine.
- SSH access to this repo (`github.com/telometto/nix-config`).
- SSH access to the private `nix-secrets` repo (provides `VARS`).

## Step 1: Clone the Repo

```bash
git clone https://github.com/telometto/nix-config.git
cd nix-config
```

## Step 2: Generate Hardware Config

Run on the target machine and place the output in the new host directory:

```bash
mkdir -p hosts/<hostname>
nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix
```

## Step 3: Create Host Directory

Create `hosts/<hostname>/` and populate it with at minimum:

- `hardware-configuration.nix` — generated above
- `packages.nix` — optional per-host package list
- `<hostname>.nix` — role, desktop flavor, and user toggles

Example `<hostname>.nix`:

```nix
{ lib, ... }:
{
  networking.hostName = lib.mkForce "<hostname>";

  sys.role.desktop.enable = true;      # or sys.role.server.enable
  sys.desktop.flavor = "gnome";       # none | kde | gnome | cosmic | hyprland; `none` is the default for servers/headless installs

  sys.users.zeno.enable = true;
}
```

All `.nix` files in the host directory (including `hardware-configuration.nix`
and `packages.nix`) are auto-imported by
[host-loader.nix](../host-loader.nix) — no explicit `imports` needed for local
files.

## Step 4: Configure SOPS

Any service that uses secrets (Tailscale, borgbackup, etc.) requires the
host's age key to be registered in `.sops.yaml` before secrets will decrypt.

These files live in the **private `nix-secrets` repository**, not in this repo.

1. Derive the age public key from the host's SSH host key:

```bash
ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key | ssh-to-age
```

2. In the `nix-secrets` repository, add the resulting age key to `.sops.yaml`
   under the new host entry.

1. Still in `nix-secrets`, re-encrypt all affected secret files:

```bash
cd ../nix-secrets
sops updatekeys path/to/affected-secret.yaml
```

Repeat `sops updatekeys` for any other secret files that should be readable
by the new host.

Until this step is complete, any secrets-enabled service will fail to start
with a SOPS decryption error.

## Step 5: Register in flake.nix

Add an entry to `nixosConfigurations` in `flake.nix`:

```nix
nixosConfigurations = {
  # ... existing hosts ...
  <hostname> = mkHost "<hostname>" [ ];
};
```

## Step 6: Build and Switch

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

This builds the system with all modules auto-imported and sets up Home Manager
for enabled users.

## Verify

- Desktop flavor applies (if enabled): KDE/GNOME/Hyprland HM bits auto-enable.
- Users exist and can log in; HM profiles are active.
- Services enabled via `sys.services.*` are running:
  ```bash
  systemctl status tailscaled   # example
  journalctl -u <service> -n 50
  ```
- Check that secrets decrypted correctly — no `sops` errors in the journal.

## Next Steps

- Add host-wide HM overrides: `home/overrides/host/<hostname>.nix`
- Add user-specific overrides: `home/overrides/user/<user>-<hostname>.nix`
- Enable additional services via `sys.services.*` in the host file or
  dedicated files under `hosts/<hostname>/`
