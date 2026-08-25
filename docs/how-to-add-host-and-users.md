# How-to: Add a Host and Enable Users

Problem: Add a new machine to the flake and enable specific users' accounts and Home Manager profiles on that machine.

## Steps

1. Create a host folder under `hosts/<hostname>/` with:

- `<hostname>.nix`
- `hardware-configuration.nix`
- `packages.nix` (optional)

2. Toggle roles and desktop flavor in `<hostname>.nix`:

```nix
sys.role.server.enable = true;   # for servers
# or
sys.role.desktop.enable = true;  # for desktops/laptops
sys.desktop.flavor = "kde";     # kde | gnome | hyprland
```

3. Enable users from `VARS` in `<hostname>.nix`:

```nix
sys.users.<username>.enable = true;  # e.g., zeno
```

### UID policy

The private `VARS.users` registry pins `zeno` to UID `1000`; other users omit
`uid` and use NixOS allocation. On a fresh host where `zeno` is enabled and
UID `1000` is free, this gives `zeno` that UID and leaves later new accounts to
the next free IDs. On an existing host, NixOS preserves the UID of an existing
named account and allocates a free UID only for a new account.

The order of entries in `VARS.users` does not control allocation. The explicit
`zeno` pin is also not a UID migration: if UID `1000` is already assigned to a
different account, enabling `zeno` can conflict, and changing a UID does not
rewrite ownership of existing files. Check the host's current account and file
ownership state before treating a reimage or UID change as routine.

4. Register the host in `flake.nix`:

```nix
nixosConfigurations = {
  # ... existing hosts ...
  <hostname> = mkHost "<hostname>" [ ];
};
```

5. Configure SOPS for the new host if it will run any secrets-enabled services
   such as Tailscale or borgbackup. Follow
   [SOPS Setup Guide](sops-setup-guide.md) to derive the host's age recipient,
   update the private `nix-secrets` repository, and re-encrypt affected secret
   files.

1. (Optional) Add Home Manager overrides:

- Host-wide: `home/overrides/host/<hostname>.nix`
- User-wide: `home/overrides/user/<user>.nix`
- User@host specific: `home/overrides/user/<user>-<hostname>.nix`

7. Build or switch:

```bash
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#<hostname>
```

## Recipes

**Enable a VM on blizzard:**

```nix
# In hosts/blizzard/virtualisation/microvms.nix
sys.virtualisation.microvm.instances.searx = {
  enable = true;
  # VM options
};
```

**Add a per-host HM override:**

```nix
# home/overrides/host/<hostname>.nix
{ ... }:
{
  hm.programs.terminal.enable = true;
  programs.git.extraConfig.core.autocrlf = false;
}
```

**Add a cross-host per-user override:**

```nix
# home/overrides/user/<username>.nix
{ lib, ... }:
{
  hm.langs = lib.mkDefault "nb_NO.UTF-8";
}
```

**Add a per-user@host override:**

```nix
# home/overrides/user/<username>-<hostname>.nix
{ ... }:
{
  hm.desktop.kde.enable = true;
  programs.ssh.matchBlocks."internal" = {
    hostname = "192.168.2.10";
    user = "admin";
  };
}
```

**Add a service to a host:**

```nix
# In the host's .nix file or a service-specific file under hosts/<hostname>/
sys.services.grafana.enable = true;
```

## Notes

- System modules are auto-loaded by `system-loader.nix`.
- HM modules are auto-loaded by `hm-loader.nix`, with overrides injected by `modules/core/home-users.nix`.
- Secrets and tokens are provided by your private `nix-secrets` flake (see `flake.nix` and `modules/core/sops.nix`).

## Troubleshooting

- **User missing**: Ensure `sys.users.<username>.enable = true` and that the
  user exists in `VARS.users`.
- **HM not applying**: Confirm `sys.home.enable = true` (defaults to true under
  roles) and check overrides file names match the expected pattern.
- **Service secrets**: Enable the service option first; `modules/core/sops.nix`
  defines secrets only when the service is on.
- **SOPS decryption fails**: Use the checklist in
  [SOPS troubleshooting](sops-setup-guide.md#troubleshooting).
