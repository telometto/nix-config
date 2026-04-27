# Explanation: Design & Rationale

This repo aims for fast onboarding and consistent configuration across machines by standardizing on loaders, roles, and secrets.

## Loaders

The system loader ([`system-loader.nix`](../system-loader.nix)) removes manual imports. Any `.nix` under [`modules/`](../modules) is in scope, so features are discoverable and uniformly available to every host. The home loader ([`hm-loader.nix`](../hm-loader.nix)) provides the same for Home Manager, giving every user the full set of `hm.*` options without any import wiring.

The HM loader's exclusion of `overrides/host/` and `overrides/user/` is intentional. Overrides must be opted into per host or user so they do not bleed across machines. A host override for `blizzard` should never silently apply to `snowfall`. The host-loader receiving `hostname` via `specialArgs` means each host's config is completely isolated in its own directory tree — renaming a directory is all you need to move a host configuration.

Trade-offs:

- Pros: Less boilerplate, fewer import mistakes, easy module growth.
- Cons: Requires naming discipline and clear option namespaces (`sys.*`, `hm.*`). A misplaced file lands in scope immediately without warning.

## Roles

Roles encapsulate bundles of sensible defaults for desktops and servers. Enabling a role flips multiple features and sets a baseline, keeping host files succinct while remaining override-friendly.

The desktop role enables: Lanzaboote (Secure Boot), Plymouth (boot splash), PipeWire (audio), Flatpak, gaming/Steam integration, NetworkManager, Tailscale, and Home Manager. The server role enables: Lanzaboote, networkd (instead of NetworkManager), monthly auto-upgrade with a deploy SSH key, NFS-awareness, Tailscale, and Home Manager. Both roles share Lanzaboote, Tailscale, and Home Manager as a common baseline. Neither role is a sealed abstraction — any setting it enables can be overridden in the host file with `lib.mkForce` or simply set to a different value after the role applies.

## Users via `VARS`

Users and their properties (shell, groups, SSH keys) are defined centrally in the private `nix-secrets` flake as `VARS.users.*`. Per-host enable toggles (`sys.users.<username>.enable`) prevent accidental account sprawl and make user presence explicit per machine.

`VARS.users` is the canonical user registry. The host file only needs `sys.users.<name>.enable = true` — no duplication of SSH keys, groups, or shell configuration. This means user properties are updated in one place (`nix-secrets`) and take effect across all machines on the next rebuild. Adding an SSH key for a user is a one-line change in `nix-secrets`, not a multi-host edit.

## Home Manager

Home Manager integrates at the NixOS level for each enabled user, merging a shared template, optional extra modules, and both host-wide and user@host overrides. Desktop flavors auto-signal HM to enable relevant pieces (`hm.desktop.<flavor>.enable = true`).

Config is assembled in seven layers. `home/*.nix` module defaults sit at the bottom, followed by the `sys.home.template` set in the host file, then the full set of HM loader modules, then the auto-enabled desktop flavor, then the per-host override (`home/overrides/host/<hostname>.nix`), then the per-user@host override (`home/overrides/user/<username>-<hostname>.nix`), and finally `sys.home.users.<username>.extraConfig` at the top. `lib.mkForce` in any override file always wins regardless of layer. `home/base.nix` provides the defaults — most programs are enabled by default — so opting out is more common than opting in.

## Secrets

`sops-nix` config defines secrets only when their corresponding services are enabled. This removes dangling secret references and simplifies onboarding: turn a service on, and its secrets mapping appears automatically; turn it off, and the mapping disappears.

The `whenEnabled` pattern makes this precise: secret definitions are wrapped in `lib.mkIf cfg.enable { sops.secrets.X = ...; }`. Disabling a service automatically removes its secret definition, preventing decryption rules that would fail on hosts where that service is not running. The `sys.secrets.*` bridge exposes runtime paths (e.g., `config.sys.secrets.gitea.dbPassword`) as plain strings. Service modules never import SOPS directly — they read a path string. This keeps service modules decoupled from the secret management backend and makes them testable without real secrets present.

## Why Flakes

Reproducibility across hosts, clean input pinning, and ergonomic per-host switching (`nixos-rebuild --flake .#<hostname>`). Checks and formatters are exposed as flake outputs. The flake lock file is the single source of truth for all nixpkgs and input versions across every machine.

## Why No Hardened Kernel in VMs

The MicroVM base uses `pkgs.linuxPackages` (the standard kernel), not `pkgs.linuxPackages_hardened`. This is intentional for compatibility: the hardened kernel disables BPF JIT and other kernel features that some services require (e.g., certain monitoring and container workloads). The security surface is instead reduced via sysctl hardening, AppArmor profiles, blacklisted kernel modules, and a restrictive per-VM firewall. This gives most of the security benefit without the compatibility cost.

## Why disko is Not Active

disko is wired into every `mkHost` call but `hosts/snowfall/disko.nix` is the only file that exists for it, and it is commented out "on hold". Disk partitioning on all existing machines is handled manually via `hardware-configuration.nix`. disko would be valuable for reproducible fresh installs but the existing machines are already partitioned and there is no need to repartition them. The wiring is in place so it can be activated when provisioning a new host from scratch.

## Why No `overlays/` Directory

Overlays live inline in `modules/core/overlays.nix` (options: `sys.overlays.fromInputs`, `sys.overlays.custom`) rather than a conventional `overlays/` directory. This keeps overlay logic under the `sys.*` option namespace so hosts can opt in or out via standard NixOS module options, and the overlays are subject to the same conditional enablement pattern as every other module (`lib.mkIf cfg.enable`). A standalone `overlays/` directory would be imported unconditionally and bypass this control.

## Why x86_64-linux Only

The flake hard-pins `system = "x86_64-linux"` in `flake.nix`. All current machines are x86_64. Adding aarch64 support would require multi-system outputs (e.g., via `flake-utils` or manual per-system attribute sets) and per-platform testing. This constraint is noted in [`docs/reference-architecture.md`](reference-architecture.md#flake).

## Evolving the Repo

- Add modules under `modules/` and expose options under `sys.*`.
- Prefer role additions when defaults suit classes of machines.
- Keep sensitive data out of this repo; extend `nix-secrets` (`VARS`) when needed.
- New PIM account modules go under `home/accounts/` — auto-loaded via `hm-loader.nix`.
