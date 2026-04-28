# Reference: Architecture & Options

Information reference for this repo's moving parts, options, and commands.

## Flake

`system` is hard-pinned to `x86_64-linux` in `flake.nix`. All machines are x86_64.

### Outputs

| Output | Description |
|--------|-------------|
| `nixosConfigurations.{snowfall,blizzard,avalanche,kaizer}` | The four physical hosts |
| `nixosConfigurations.<vm-name>` (×23) | MicroVM guests defined in `vms/` |
| `formatter.x86_64-linux` | treefmt wrapper (`nix fmt`) |
| `checks.x86_64-linux.formatting` | Formatting check (`nix flake check`) |
| `devShells.x86_64-linux.default` | Dev shell with nil, nixfmt, deadnix, statix, sops, ssh-to-age |

### `mkHost` — what it always injects

Every physical host built with `mkHost` automatically receives:

- `system-loader.nix` — imports all modules
- `host-loader.nix` — imports all files under `hosts/<hostname>/`
- `home-manager` NixOS module
- `sops-nix` NixOS module
- `lanzaboote` NixOS module
- `microvm.host` NixOS module
- `quadlet-nix` NixOS module
- `disko` NixOS module (wired in but not active; see [Why disko is not active](explanation-design.md#why-disko-is-not-active))

`specialArgs` available in every module: `inputs`, `system`, `VARS`, `consts`, `self`, `hostname`.

______________________________________________________________________

## Loaders

Three auto-import helpers eliminate manual import lists.

### `system-loader.nix`

Recursively imports every `.nix` file found under `./modules/`. No exclusions. Any new file placed under `modules/` is immediately in scope for all hosts.

### `host-loader.nix`

Recursively imports every `.nix` file under `./hosts/${hostname}/`. The `hostname` value comes from `specialArgs`, so each host's config is fully isolated in its own directory tree.

### `hm-loader.nix`

Recursively imports every `.nix` file under `./home/`, **excluding** any path containing `/overrides/host/` or `/overrides/user/`. Overrides are excluded so they must be opted into explicitly per host or user — they do not bleed across machines. See [HM Override System](#hm-override-system) below.

______________________________________________________________________

## System Options (`sys.*`)

All NixOS-level options are defined under the `sys.*` namespace in `modules/`.

| Namespace | Defined in | Purpose |
|-----------|-----------|---------|
| `sys.role.{desktop,server}.enable` | `modules/core/roles.nix` | Machine role selection |
| `sys.desktop.flavor` | `modules/desktop/base.nix` | Desktop env enum: `none` / `gnome` / `kde` / `hyprland` / `cosmic` |
| `sys.users.<name>.enable` | `modules/core/user-options.nix` | Per-host user toggle |
| `sys.home.*` | `modules/core/home-options.nix` | HM integration (`enable`, `template`, `users.*`) |
| `sys.secrets.*` | `modules/security/secrets.nix` | Runtime secret path strings (`nullOr str`) |
| `sys.boot.lanzaboote.enable` | `modules/boot/secureboot.nix` | Secure Boot via lanzaboote |
| `sys.boot.plymouth.*` | `modules/boot/plymouth.nix` | Boot splash screen |
| `sys.networking.{base,networkd,networkmanager}.enable` | `modules/networking/` | Networking stack selection |
| `sys.programs.*` | `modules/programs/` | ssh, gaming, java, gnupg, nix-ld, etc. |
| `sys.services.*` | `modules/services/` | ~60 service modules |
| `sys.storage.filesystems.*` | `modules/storage/filesystems.nix` | Filesystem options |
| `sys.virtualisation.*` | `modules/virtualisation/` | libvirt, microvm, k3s, general enable |
| `sys.hardware.nvidia.*` | `modules/hardware/nvidia.nix` | NVIDIA GPU configuration |
| `sys.nix.distributedBuilds.*` | `modules/core/distributed-builds.nix` | Remote build targets |
| `sys.overlays.*` | `modules/core/overlays.nix` | Nixpkgs overlays (`fromInputs`, `custom`) |

______________________________________________________________________

## Home Manager Options (`hm.*`)

All Home Manager options are defined under the `hm.*` namespace in `home/`.

| Namespace | Defined in | Purpose |
|-----------|-----------|---------|
| `hm.langs` | `home/base.nix` | Default locale |
| `hm.desktop.{gnome,kde,hyprland,xdg}.enable` | `home/desktop/` | Desktop environment integration |
| `hm.programs.{browsers,development,terminal,media,social,gaming,gpg,tools,beets,fastfetch,packages}.enable` | `home/programs/` | User program bundles |
| `hm.services.{gpgAgent,sshAgent}.enable` | `home/services/` | User-level background services |
| `hm.security.sops.*` | `home/security/sops.nix` | User-level SOPS secret decryption |
| `hm.accounts.{email,calendar,contact}.enable` | `home/accounts/` | PIM accounts (email, calendar, contacts) |
| `hm.files.enable` | `home/files/files.nix` | Managed dotfiles |

______________________________________________________________________

## HM Override System

Home Manager config is assembled in layers. Lower layers supply defaults; higher layers win.

| Layer | File / mechanism | Scope |
|-------|-----------------|-------|
| 1. Module defaults | Individual `home/*.nix` option defaults | All users, all hosts |
| 2. HM loader modules | All files under `home/` (via hm-loader) | All users, all hosts |
| 3. Host-wide extra modules | `sys.home.extraModules` in host file | All users on that host |
| 4. Base template | `sys.home.template` in host file | All users on that host |
| 5. Auto desktop | `hm.desktop.<flavor>.enable = true` from `sys.desktop.flavor` (via `lib.mkDefault`) | All users on hosts with a desktop flavor |
| 6. Host override | `home/overrides/host/<hostname>.nix` | All users on that specific host |
| 7. User@host override | `home/overrides/user/<username>-<hostname>.nix` | Specific user on specific host |
| 8. User extra modules | `sys.home.users.<username>.extraModules` in host file | Specific user on that host |
| 9. `extraConfig` | `sys.home.users.<username>.extraConfig` in host file | Specific user on that host |

`lib.mkForce` in any override file always wins regardless of layer.

### The `ssh-common.nix` exception

`home/overrides/host/ssh-common.nix` is a shared SSH match-block config that is **not** named after a hostname. It is imported manually by individual host override files (e.g. `home/overrides/host/blizzard.nix` imports it). It is **not** auto-imported by `hm-loader.nix` (overrides are excluded from the loader) nor is it picked up automatically by `home-users.nix`. To share SSH config across multiple hosts, each relevant host override file imports `ssh-common.nix` explicitly.

______________________________________________________________________

## Roles

Roles bundle sensible defaults for classes of machines. Enable in a host file:

```nix
sys.role.desktop.enable = true;
# or
sys.role.server.enable = true;
```

| Feature | Desktop role | Server role |
|---------|:-----------:|:-----------:|
| Lanzaboote (Secure Boot) | yes | yes |
| Tailscale | yes | yes |
| Home Manager | yes | yes |
| Plymouth (boot splash) | yes | no |
| PipeWire (audio) | yes | no |
| Flatpak | yes | no |
| Gaming / Steam | yes | no |
| NetworkManager | yes | no |
| networkd | no | yes |
| Monthly auto-upgrade | no | yes |
| NFS awareness | no | yes |

Neither role is a sealed abstraction — any setting it enables can be overridden in the host file.

Config files: [`modules/role-desktop.nix`](../modules/role-desktop.nix), [`modules/role-server.nix`](../modules/role-server.nix).

______________________________________________________________________

## Stack

Operational tools used across the repo.

| Tool | Purpose | Config |
|------|---------|--------|
| treefmt-nix | Formatter orchestrator | `treefmt.nix` |
| nixfmt | Nix file formatter | `treefmt.nix` |
| shfmt | Shell script formatter (2-space indent, `-ci -sr`) | `treefmt.nix` |
| yamlfmt | YAML formatter (excludes `.github/workflows/`) | `treefmt.nix` |
| mdformat | Markdown formatter | `treefmt.nix` |
| jsonfmt | JSON formatter | `treefmt.nix` |
| ruff | Python formatter | `treefmt.nix` |
| sops-nix | Secret decryption at activation time | `modules/core/sops.nix` |
| lanzaboote | Secure Boot (both roles) | `modules/boot/secureboot.nix` |
| disko | Disk layout (included but not active) | `hosts/snowfall/disko.nix` (on hold) |
| auto-upgrade | Monthly NixOS upgrades (server role only) | `modules/services/auto-upgrade.nix` |

`nix flake check` only runs the `checks.formatting` check. Full host evaluation (build testing) is done by the `validate-config.yml` CI workflow, not as a flake check.

______________________________________________________________________

## Secrets Flow

Secrets are handled across three layers. The private `nix-secrets` flake contains the raw secret values encrypted with age keys. `sops-nix` decrypts them at system activation using the host's age key derived from its SSH host key. The decrypted value is written to a path under `/run/secrets/`.

The bridge between SOPS and service modules is the `sys.secrets.*` option namespace. Service modules never import SOPS directly; they read a path string exposed by `modules/core/sops.nix` (e.g. `config.sys.secrets.gitea.dbPassword`). This keeps service modules decoupled from the secret management backend.

The `whenEnabled` pattern ties secret definitions to service enablement. A secret is only declared in `sops.secrets` when its corresponding service module is enabled (`lib.mkIf cfg.enable { sops.secrets.X = ...; }`). Disabling a service automatically removes its secret definition, preventing dangling decryption rules that would fail on hosts where that service is not running.

See also: [Architecture Blueprint — Section 8: Secrets Architecture](Project_Architecture_Blueprint.md#section-8---secrets-architecture) for a full diagram.

______________________________________________________________________

## VM Registry & MicroVM Helper

VMs do **not** use `system-loader.nix`. They are built with a minimal module set assembled by `vms/flake-microvms.nix::mkMicrovm`, which provides only what a VM needs. The physical hosts that run VMs use `microvm.host` (injected by `mkHost`).

- [`vms/vm-registry.nix`](../vms/vm-registry.nix): Central data registry. Single source of truth for CID, MAC, IP, port, memory, vCPU, gateway, and DNS per VM.
- [`vms/mkMicrovmConfig.nix`](../vms/mkMicrovmConfig.nix): Helper function that generates common MicroVM infrastructure config (hypervisor, networking, volumes, shares) from a registry entry. Each VM file imports this and passes its registry entry plus any extra volumes or shares.
- [`vms/base.nix`](../vms/base.nix): Shared hardened base config for all VMs. Includes SSH host keys, admin user, firewall, and stateVersion.

See [`vms/README.md`](../vms/README.md) for the full VM list and per-VM details.

______________________________________________________________________

## Podman Containers (quadlet-nix)

- Backend: [quadlet-nix](https://github.com/SEIAROTg/quadlet-nix) — Podman Quadlet systemd integration.
- Container definitions: [`containers/`](../containers/) (Home Manager modules; imported explicitly by hosts into `home-manager.users.<user>`).
- Rootless containers use `virtualisation.quadlet.containers` in HM config. The owning user needs `linger = true` and `autoSubUidGidRange = true`.
- Rootful containers (e.g., inside MicroVMs) use `virtualisation.quadlet.containers` at the NixOS system level.
- Requires `sys.virtualisation.enable = true` on the host (provides Podman + quadlet via [`modules/virtualisation/virtualisation.nix`](../modules/virtualisation/virtualisation.nix)).

______________________________________________________________________

## Traefik Helpers (`lib/traefik.nix`)

- `mkSecurityHeaders { ... }`: Generate Traefik middleware attrsets with customisable security response headers (X-Frame-Options, CSP, etc.). Pass `null` to any header to omit it.
- `mkRoutes { domain; defaultMiddlewares? }`: Generate `{ routers; services; }` from a concise routing table mapping service names to subdomains and URLs.
- `mkReverseProxyOptions`, `mkTraefikDynamicConfig`, `mkCfTunnelAssertion`: Per-service reverse proxy options used by `modules/services/*.nix`.

______________________________________________________________________

## Constants (`lib/constants.nix`)

Centralises shared magic strings: Tailscale domain suffix, Cloudflare account/policy IDs. Imported once in `flake.nix` and passed into modules as `consts` via `specialArgs` (and similarly for MicroVMs in `vms/flake-microvms.nix`). Prefer the injected `consts` argument over ad-hoc direct imports.

______________________________________________________________________

## Commands

```bash
# Apply configuration (requires root; switches immediately)
sudo nixos-rebuild switch --flake .#<hostname>

# Test activation without making it the boot default
sudo nixos-rebuild test --flake .#<hostname>

# Dry run — show what would change
nixos-rebuild dry-run --flake .#<hostname>

# Build without activating
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel

# Format all files (nixfmt, shfmt, yamlfmt, mdformat, jsonfmt, ruff)
nix fmt

# Check formatting only (not a full host evaluation)
nix flake check
nix flake check --no-build   # skip builds

# Dev shell (includes nil, nixfmt, deadnix, statix, sops, ssh-to-age)
nix develop
```

______________________________________________________________________

## Conventions

- Put new system modules under `modules/` — they're auto-loaded via `system-loader.nix`.
- Put HM modules under `home/` — they're auto-loaded via `hm-loader.nix`.
- Use `sys.*` options to opt in features; avoid ad-hoc host edits when a module already exists.
- Use overrides under `home/overrides/*` for per-host or per-user adjustments.
- Use `home/overrides/host/ssh-common.nix` for shared SSH matchBlocks; import it from each host override that needs it.
- Put new PIM account modules under `home/accounts/` — they're auto-loaded via `hm-loader.nix`.
- Keep sensitive data out of this repo; extend `nix-secrets` (`VARS`) when needed.
- Module pattern: `options.sys.<category>.<name>.enable = lib.mkEnableOption "..."` with `config = lib.mkIf cfg.enable { ... }`.

______________________________________________________________________

## See Also

- [Architecture Blueprint](Project_Architecture_Blueprint.md) — comprehensive diagrams and detailed explanations
- [Explanation: Design](explanation-design.md) — rationale behind key decisions
- [How-To: Add Hosts and Users](how-to-add-host-and-users.md) — step-by-step task guide
- [vms/README.md](../vms/README.md) — VM list and configuration details
- [modules/README.md](../modules/README.md) — system modules overview
