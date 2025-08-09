# nix-config

Unified, role-aware NixOS + Home Manager flake.

## Layout
- `flake.nix`: Inputs, host map, overlays, dev shell, checks.
- `lib/default.nix`: Role resolution (desktop/laptop/server) + mk* helpers.
- `shared/constants.nix`: Centralized literals (network CIDRs, exports, backup repo).
- `shared/system.nix`: Core system module; imports service abstractions and sets global options.
- `modules/services/*.nix`: Reusable abstractions (`tailscale`, `nfs-exports`, `borgbackup`).
- `devices/<host>.nix`: Per-device hardware + strictly device-specific settings (minimal duplication).
- `hosts/<host>/configuration.nix`: Host assembly (imports shared modules, profile, device module, users).
- `shared/profiles/*.nix`: Role profiles (desktop/laptop/server).
- `shared/desktop-environments/*`: DE-specific system-level settings.
- `home/` + `shared/home.nix`: Home Manager shared config; per-user configs under `hosts/<host>/home/users/...`.

## my.* Namespaces
Custom option namespaces introduced:
- `my.tailscale` for flag derivation based on role.
- `my.nfs` for declarative exports.
- `my.backups` for borg jobs.

## Adding a New Host
1. Add hostname to secrets VARS (matching role).
2. Create `devices/<hostname>.nix` with only hardware / unique config.
3. Add entry in `flake.nix` `hosts` attrset.
4. Create `hosts/<hostname>/configuration.nix` importing shared modules + device module.
5. Add home-manager user config under `hosts/<hostname>/home/users/<user>/home.nix`.

## Assertions
`shared/system.nix` asserts role must resolve; misconfigured hostnames fail early.

## Formatting & QA
`nix flake check` runs Alejandra (format), deadnix, statix.

## Future Ideas
- Additional roles or tags (e.g., `gpu`, `builder`).
- Service health modules (monitoring abstractions).

## Security Notes
- AppArmor, Secure Boot, TPM2 enabled.
- Secrets via sops-nix.

