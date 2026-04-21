# Copilot / Cloud Agent Instructions

Onboarding notes for agents working on `telometto/nix-config`. Read this
before exploring — it captures environment constraints and conventions that
are not obvious from a surface-level look at the tree.

## 1. What this repository is

A modular **NixOS flake** that configures several x86_64-linux hosts plus a
set of MicroVMs. It uses:

- **Nix flakes** (`flake.nix`) as the single entry point.
- **Auto-loading module system**: every `.nix` file under `modules/` is
  imported by [`system-loader.nix`](../system-loader.nix); every `.nix`
  under `home/` (except `overrides/`) is imported by
  [`hm-loader.nix`](../hm-loader.nix); every `.nix` under
  `hosts/<hostname>/` is imported by [`host-loader.nix`](../host-loader.nix).
- **Role modules** (`modules/role-desktop.nix`, `modules/role-server.nix`)
  that bundle sensible defaults.
- **Home Manager** as a NixOS module, keyed off the user list in `VARS`.
- **sops-nix** for secrets, sourced from the private `nix-secrets` flake.
- **disko**, **lanzaboote** (Secure Boot), **microvm.nix**, **quadlet-nix**,
  **hyprland**, **nur**, **nix-colors**, **treefmt-nix**.

Hosts live under `hosts/`:

| Host | Role | Desktop |
| --------- | ------- | -------- |
| snowfall | Desktop | KDE |
| blizzard | Server | — |
| avalanche | Desktop | GNOME |
| kaizer | Desktop | KDE |

MicroVMs are merged into `nixosConfigurations` from
[`vms/flake-microvms.nix`](../vms/flake-microvms.nix).

## 2. Critical environment constraint (read first)

`flake.nix` declares the input:

```nix
nix-secrets.url = "git+ssh://git@github.com/telometto/nix-secrets.git";
```

This is a **private repository pulled over SSH**. The cloud agent sandbox
does **not** have the deploy key that CI uses (`secrets.SSH_DEPLOY_KEY`
via `webfactory/ssh-agent`). As a direct consequence, inside the agent
sandbox the following commands will **fail** or cannot be fully trusted:

- `nix flake check`
- `nix flake update` / `nix flake lock`
- `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel`
- `nix build .#nixosConfigurations.<host>...`
- `nixos-rebuild` (also needs root / a real NixOS host)
- Anything that forces evaluation of a host config — which is basically
  everything that touches `VARS`, `sys.users.*`, or `home-manager` wiring.

**Do not** try to “fix” these failures by modifying the `nix-secrets` input,
committing secrets, inlining `VARS`, or removing the SSH dependency. The
authoritative validation happens in GitHub Actions (`Flake Check`,
`Configuration Validation`), which does have the deploy key.

What you *can* do locally in the sandbox:

- Read and edit files.
- Run `nix fmt` / `treefmt` if Nix is available (formatting does not require
  evaluating host configs, but it does need the flake inputs that are not
  behind SSH — if the initial fetch fails, skip formatting and rely on the
  `Auto Format` workflow to format on push).
- `nix-instantiate --parse <file>.nix` to syntax-check a single file without
  evaluating the flake.
- Reason about changes statically and rely on CI to validate.

If a change *must* be validated and `nix flake check` cannot run, say so
explicitly in the PR description rather than silently skipping validation.

## 3. Repository layout

```
flake.nix                     # entry point, defines mkHost and outputs
flake.lock                    # pinned inputs (managed by update workflows)
system-loader.nix             # auto-imports every .nix under modules/
host-loader.nix               # auto-imports every .nix under hosts/<hostname>/
hm-loader.nix                 # auto-imports home/ (excluding overrides/)
treefmt.nix                   # formatter config

modules/                      # System (NixOS) modules, sys.* namespace
  role-desktop.nix            # Role bundle: desktop defaults
  role-server.nix             # Role bundle: server defaults
  boot/ core/ desktop/ hardware/ networking/ programs/
  security/ services/ storage/ virtualisation/

home/                         # Home Manager modules, hm.* namespace
  base.nix                    # shared HM defaults
  accounts/ desktop/ files/ programs/ security/ services/
  overrides/host/<host>.nix   # optional host-wide HM override
  overrides/user/<user>-<host>.nix  # optional user@host HM override

hosts/<hostname>/             # Per-host config
  <hostname>.nix              # toggles roles, users, services
  hardware-configuration.nix  # hardware specifics
  disko.nix (optional)        # disk layout
  packages.nix (optional)
  containers.nix (optional)

vms/                          # MicroVM definitions, merged into nixosConfigurations
lib/                          # Shared helpers (constants, traefik, grafana)
docs/                         # Human documentation (see docs/README.md)
.github/workflows/            # CI: flake-check, validate-config, auto-format, etc.
.github/scripts/              # Shared workflow helpers (redact-secrets.sh, comment.js)
```

## 4. Conventions you must follow

### 4.1 Module pattern

Every system module under `modules/` looks like:

```nix
{ lib, config, ... }:
let
  cfg = config.sys.<category>.<name>;
in
{
  options.sys.<category>.<name> = {
    enable = lib.mkEnableOption "…";
    # …
  };

  config = lib.mkIf cfg.enable {
    # NixOS config
  };
}
```

Home Manager modules under `home/` use the same pattern but with the
`hm.<category>.<name>` namespace.

### 4.2 Auto-loading means: do not add manual `imports`

Never add a file under `modules/` or `home/` to an `imports = […]` list —
it is already imported. Conversely, creating a new file in those trees is
enough to activate it; there is no registry file to update.

Files that are deliberately excluded from auto-loading:

- `home/overrides/host/**` and `home/overrides/user/**` — picked up
  conditionally by `modules/core/home-users.nix`.

### 4.3 Users come from `VARS`

Users are defined centrally in the private `nix-secrets` flake (`VARS.users`).
You cannot add a new user without editing that repo. You **can** toggle
existing users per host with `sys.users.<username>.enable = true;` in
`hosts/<hostname>/<hostname>.nix`.

### 4.4 Secrets

- Use `sops-nix` via `modules/core/sops.nix`.
- Secret files live in the `nix-secrets` flake — do not commit secrets,
  SSH keys, age keys, `.sops.yaml` mappings, or `vars/` content here.
- `.gitignore` already excludes `nix-secrets/`, `vars/`, `result`.

### 4.5 Option namespaces

- System options: `sys.*` (e.g. `sys.role.desktop.enable`,
  `sys.desktop.flavor`, `sys.services.tailscale.enable`,
  `sys.users.<name>.enable`).
- Home Manager options: `hm.*`.
- Desktop flavor values: `"kde" | "gnome" | "hyprland"`. Setting
  `sys.desktop.flavor` auto-enables the matching `hm.desktop.<flavor>`.

## 5. Formatting, linting, validation

### Format

`nix fmt` runs treefmt (`treefmt.nix`) with:

- `nixfmt` for `*.nix`
- `shfmt` (2-space, `-ci`, `-sr`) for `*.sh`/`*.bash`
- `yamlfmt` for `*.yml`/`*.yaml` **except `.github/workflows/*.{yml,yaml}`**
  — workflows are intentionally excluded (see `treefmt.nix` globals).
- `mdformat` for `*.md`
- `jsonfmt` for JSON
- `ruff` (format + lint) for Python

If you can't run `nix fmt` in the sandbox, the `Auto Format` workflow will
reformat on push/PR automatically. Still try to match the existing style by
hand (2-space indent, lowercase option names, trailing newlines).

### Validate locally (when possible)

- `nix-instantiate --parse path/to/file.nix` — parse check, no evaluation,
  no secrets fetch.
- `nix flake check --no-build` — full evaluation; **requires SSH to
  `nix-secrets`**.
- `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel --raw`
  — evaluates a single host; same SSH requirement.
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` —
  actual build, slow, same SSH requirement.

### CI workflows (source of truth)

Relevant workflows in `.github/workflows/`:

| Workflow | Trigger | Purpose |
| -------- | ------- | ------- |
| `flake-check.yml` | PR/push on `**.nix`, `flake.lock`, `treefmt.nix` | Runs `nix flake check --no-build` |
| `validate-config.yml` | Same paths | Evaluates each host in `nixosConfigurations` in a matrix (hosts discovered by grepping `mkHost` in `flake.nix`) |
| `auto-format.yml` | PR / push to `main`/`testing` | Runs `nix fmt` and pushes a formatting commit |
| `compliance-check.yml`, `security-audit.yml`, `health-check.yml`, `change-impact-analysis.yml`, `doc-drift.yml`, `flake-freshness.yml` | Various | Repository hygiene checks |
| `update-nix-lock.yml` | Schedule (every 3 h) + manual | Incremental `nix flake lock --update-input …` PRs |
| `update-nix-lock-recreate.yml` | Schedule (monthly) + manual | `nix flake update --recreate-lock-file` |
| `update-dashboards.yml` | Manual / schedule | Refresh Grafana dashboards under `dashboards/` |

Auto-merge for lockfile PRs is gated on `Flake Check` and
`Configuration Validation` passing.

## 6. Making changes — typical recipes

### Add a new system feature (e.g. a service toggle)

1. Create `modules/<category>/<name>.nix` using the module pattern above
   with options under `sys.<category>.<name>.*`.
1. Do **not** add it to any `imports` list.
1. Enable it per host from `hosts/<hostname>/<hostname>.nix`.
1. Update `docs/reference-architecture.md` if the option is user-facing.

### Add a new host

Follow `docs/how-to-add-host-and-users.md`:

1. `hosts/<hostname>/<hostname>.nix` + `hardware-configuration.nix`
   (+ `disko.nix`, `packages.nix` as needed).
1. Add `<hostname> = mkHost "<hostname>" [ ];` to `nixosConfigurations` in
   `flake.nix`. The `validate-config.yml` workflow discovers hosts by
   grepping for `mkHost` — keep the spacing `name = mkHost` intact so the
   regex `^\s+\K\w+(?=\s*=\s*mkHost)` still matches.

### Add a new Home Manager module

1. Create `home/<category>/<name>.nix` under `hm.<category>.<name>`.
1. Opt-in from `home/base.nix` or from a host/user override under
   `home/overrides/`.

### Update inputs

Prefer letting `update-nix-lock.yml` do it. If you must update locally,
you need SSH access to `nix-secrets`; otherwise open an issue / ping the
maintainer instead of guessing lock hashes.

## 7. Things to avoid

- Removing or renaming `VARS`, `consts`, `self`, `hostname`, `system`,
  `inputs` from `specialArgs` in `flake.nix` — many modules depend on them.
- Importing files from `modules/` or `home/` explicitly (breaks the
  auto-loader contract, or causes double-imports).
- Committing anything that looks like a secret, TLS key, age/sops identity,
  `.sops.yaml`, or the `vars/` directory. They are git-ignored for a reason.
- Editing `.github/workflows/*.yml` formatting with `yamlfmt` (treefmt
  already excludes them; reformatting can break CI).
- Adding new linters/builders/test frameworks unless explicitly required —
  prefer the tools already configured in `treefmt.nix`.
- Using `--depth=1` clones or shallow fetches when you need to inspect
  history; this repo assumes standard git access.

## 8. Known friction / workarounds

- **Flake evaluation fails with "Permission denied (publickey)" or
  "could not read from remote repository"** when touching `nix-secrets`.
  Expected in the sandbox. Validate via CI instead.
- **`magic-nix-cache-action` is used in CI** to speed builds. Locally,
  expect cold builds.
- `paperless-ngx` has a build workaround in `vms/flake-microvms.nix`
  (`doCheck = false; doInstallCheck = false;`). Preserve it unless you
  are deliberately re-testing upstream.
- Documentation is LLM-assisted (see footers in `README.md` and
  `modules/README.md`) — prefer verifying against code before trusting a
  doc claim.

## 9. Where to look first

- Big picture: [`docs/Project_Architecture_Blueprint.md`](../docs/Project_Architecture_Blueprint.md)
- Options reference: [`docs/reference-architecture.md`](../docs/reference-architecture.md)
- How-to: [`docs/how-to-add-host-and-users.md`](../docs/how-to-add-host-and-users.md)
- Tutorial: [`docs/tutorial-provision-host.md`](../docs/tutorial-provision-host.md)
- Design rationale: [`docs/explanation-design.md`](../docs/explanation-design.md)
- Module index: [`modules/README.md`](../modules/README.md),
  [`home/README.md`](../home/README.md)

Keep changes small, follow the module pattern, and trust the CI workflows
to validate evaluation. When in doubt, read the loader you're about to
touch — the three `*-loader.nix` files are short and are the real API of
this repo.
