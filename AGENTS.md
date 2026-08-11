# Repository guidance

## Purpose

This repository defines NixOS and Home Manager configuration for four hosts:
`snowfall`, `blizzard`, `avalanche`, and `kaizer`. It keeps host and workload
changes reproducible and reviewable. The stack uses Nix flakes, sops-nix,
microvm.nix, quadlet-nix, and treefmt.

The private `nix-secrets` flake supplies user data, SSH keys, and secrets. Never
copy secret values into this repository.

## Working map

- `modules/` defines auto-loaded NixOS options under `sys.*`.
- `home/` defines auto-loaded Home Manager options under `hm.*`;
  `home/overrides/` is opt-in.
- `hosts/<hostname>/` contains auto-loaded host configuration. Register new
  hosts in `flake.nix`.
- `vms/` and `containers/` define MicroVM and Quadlet workloads; `lib/` holds
  shared helpers.

Do not add manual imports for local files under auto-loaded trees. External
modules still require explicit imports. Start with `README.md:33`, then read the
README in the area you are changing.

## Validation

Use the narrowest relevant checks:

```bash
git diff --check
nix fmt
nix flake check
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

Flake evaluation and host builds need SSH access to the private `nix-secrets`
input. If the key is unavailable, run applicable static checks and state that
Nix evaluation was not performed. Use current CI as the evaluation source of
truth; see `docs/reference-ci.md:8`. Never activate a configuration with
`nixos-rebuild switch` unless the user explicitly asks.

## Read when relevant

- Repository overview: `README.md:1`; common commands: `README.md:67`
- Architecture, options, loaders, secrets, VMs, and containers:
  `docs/reference-architecture.md:1`
- CI and local validation constraints: `docs/reference-ci.md:8`
- Complete documentation index: `docs/README.md:39`
- System modules: `modules/README.md:1`
- Home Manager and override precedence: `home/README.md:1`
- Host configuration: `hosts/README.md:1`
- MicroVMs: `vms/README.md:1`
- Quadlet containers: `containers/README.md:1`
- GitHub issues and PRDs: `docs/agents/issue-tracker.md:1`
- Triage labels: `docs/agents/triage-labels.md:1`
- Domain language and ADRs: `docs/agents/domain.md:1`
