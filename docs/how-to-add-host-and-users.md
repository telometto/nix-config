# How-to: Add a Host and Enable Users

Problem: Add a new machine to the flake and enable specific users’ accounts and Home Manager profiles on that machine.

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

4. (Optional) Add Home Manager overrides:

- Host-wide: `home/users/host-overrides/<hostname>.nix`
- User@host specific: `home/users/user-configs/<user>-<hostname>.nix`

5. Build or switch:

```bash
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#<hostname>
```

## Notes

- System modules are auto-loaded by `system-loader.nix`.
- HM modules are auto-loaded by `hm-loader.nix`, with overrides injected by `modules/core/home-users.nix`.
- Secrets and tokens are provided by your private `nix-secrets` flake (see `flake.nix` and `modules/core/sops.nix`).

## Troubleshooting

- User missing: Ensure `sys.users.<username>.enable = true` and that the user exists in `VARS.users`.
- HM not applying: Confirm `sys.home.enable = true` (defaults to true under roles) and check overrides file names.
- Service secrets: Enable the service option first; `modules/core/sops.nix` defines secrets only when the service is on.
