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

4. Register the host in `flake.nix`:

```nix
nixosConfigurations = {
  # ... existing hosts ...
  <hostname> = mkHost "<hostname>" [ ];
};
```

5. Configure SOPS for the new host (required if any secrets-enabled services
   are on — Tailscale, borgbackup, etc.):

   a. Derive the host's age recipient from its SSH host key:

   ```bash
   ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key | nix run nixpkgs#ssh-to-age --
   ```

   b. In the private `nix-secrets` repository (not this repo), add that public
   key to the appropriate host entry in `.sops.yaml`.
   c. Still in `nix-secrets`, re-encrypt each affected secret file using its
   actual path there:

   ```bash
   cd ../nix-secrets
   sops updatekeys path/to/affected-secret.yaml
   ```

   Repeat `sops updatekeys` for any other secret files that should be readable
   by the new host.

1. (Optional) Add Home Manager overrides:

- Host-wide: `home/overrides/host/<hostname>.nix`
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

**Add a per-user override:**

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
- **SOPS decryption fails**: Ensure the host's age key is in `.sops.yaml` in
  the private `nix-secrets` repository, and that all affected secret files
  there have been re-encrypted with `sops updatekeys <path>`.
