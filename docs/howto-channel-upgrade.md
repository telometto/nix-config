# How-to: Channel upgrade (24.11 → 25.11) and `stateVersion` guidance

> Audited: 2026-05-03 · Current NixOS stable: **25.11 ("Xantusia")**, released 2025-11-30
>
> **Starting state:** `flake.nix` already pins primary `nixpkgs` to `nixos-unstable`. Most
> 25.05/25.11 breaking changes (Plasma 6, `services.displayManager.*`, `services.pulseaudio`,
> flat `pkgs.gnome-*`) were absorbed into the working tree at the time they landed in unstable.
> The residual work is narrower than a typical 24.11 → 25.11 migration would be.
>
> **For the full execution checklist and per-VM Postgres upgrade procedure, see
> `plans/use-the-most-appropriate-zazzy-trinket.md`.**

______________________________________________________________________

## `stateVersion` — the rules

`stateVersion` is *not* a "channel version" knob. It records which NixOS release first
created the stateful data on a given machine, so service modules can keep using the
historical on-disk-format defaults. The NixOS manual is unambiguous:

> "Most users should never change this value after the initial install, for any reason,
> even if you've upgraded your system to a new NixOS release."
>
> "Do not change this value unless you have manually inspected all the changes it would
> make to your configuration, and migrated your data accordingly."

### The one exception — Postgres major upgrade

`services.postgresql.package` is gated on `stateVersion`:

| `stateVersion` | Default PostgreSQL major |
|---|---|
| `"24.11"` | 16 |
| `"25.11"` | 17 |

When you want to upgrade Postgres from 16 → 17, the correct NixOS procedure is:

1. Migrate the data dir with `pg_upgrade` *while Postgres is still on PG 16*.
1. **Then** bump `stateVersion` so the new default (PG 17) picks up the already-migrated data.

**Do not:**

- Bump `stateVersion` before running `pg_upgrade` — PostgreSQL 17 cannot read a PG 16 data dir.
- Add `services.postgresql.package = pkgs.postgresql_16;` as a "safe" pin — this creates
  ongoing maintenance debt and diverges from the `stateVersion`-driven default.

### `stateVersion` by host (current)

| Host / scope | `system.stateVersion` | `home.stateVersion` | Notes |
|---|---|---|---|
| `snowfall` | `"24.05"` | `"24.05"` | No SV-gated state — do not change |
| `blizzard` | `"24.11"` | `"24.11"` (forced) | No SV-gated state on host itself |
| `avalanche` | `"24.05"` | `"24.05"` | No SV-gated state — do not change |
| `kaizer` | `"24.11"` | `"24.05"` (default — mismatched) | Mismatch is harmless; see below |
| All MicroVMs | `"24.11"` (via `vms/base.nix:195`) | n/a | 8 VMs run local Postgres — see §PG |

**kaizer HM mismatch:** System is `"24.11"` but HM inherits the `"24.05"` global default from
`home/base.nix:82`. Harmless in practice. Normalize with `home/overrides/host/kaizer.nix`:

```nix
{ lib, ... }: {
  home.stateVersion = lib.mkForce "24.05";
}
```

Choose `"24.05"` (matches HM defaults actually inherited so far) over `"24.11"` (matches system).

### When to set a *new* `stateVersion`

Only on a **freshly wiped disk at install time**. Set `stateVersion` to the NixOS release
you are installing from (e.g. `"25.11"` after a 25.11 disko wipe). Do not carry over the
value from the previous install.

**Partial reinstall (root formatted, data disks preserved):**

- Desktop hosts (snowfall, avalanche, kaizer): no SV-gated services. Safe to use the
  current channel's SV even with preserved home/data disks.
- `blizzard` with preserved ZFS pools (`tank`, `rpool`, `flash`): VM images on those pools
  contain PG 16 data dirs. If you reinstall root with `stateVersion = "25.11"`, the default
  Postgres inside each VM switches to PG 17 → clusters fail to start. Either keep
  `stateVersion = "24.11"` and pg_upgrade per-VM afterward, or set `"25.11"` and immediately
  migrate all VM clusters before rebooting.

______________________________________________________________________

## VMs in scope for Postgres upgrade

| VM | Application | DB volume |
|---|---|---|
| `gitea-vm` | Gitea | `/var/lib/postgresql` |
| `matrix-synapse-vm` | Synapse + MAS (shared cluster) | dedicated 100 GB `postgresql-state.img` |
| `paperless-vm` | Paperless-ngx | `/var/lib/postgresql` |
| `firefly-vm` | Firefly III | `/var/lib/postgresql` |
| `immich-vm` | Immich | dedicated `postgres-state.img` |
| `mealie-vm` | Mealie | `/var/lib/postgresql` |
| `actual-vm` | Actual | `/var/lib/postgresql` |
| `adguardhome-vm` | AdGuard Home | `/var/lib/postgresql` |

`searx-vm` uses Redis/Valkey — not in scope.

______________________________________________________________________

## PR strategy for the 24.11 → 25.11 migration

Three PR batches, sequenced so each can be merged independently:

**PR 1 — Code changes, no data migration**

- `flake.nix`: collapse `nixpkgs-stable-latest` + `nixpkgs-stable@24.11` → single `nixpkgs-stable@25.11`.
- `modules/services/matrix-synapse.nix`: swap `postgresql.service` → `postgresql.target` in 4 systemd units (25.11 introduces `postgresql.target` to guarantee schema-ready DB).
- `modules/services/matrix-authentication-service.nix`: same swap + add `wants = [ "network-online.target" ]` for the remote-DB code path.
- `vms/base.nix:195` **stays at `"24.11"`** — no VM Postgres cluster is affected.

**PRs 2..9 — One per Postgres VM, lowest-stakes first**

Recommended order: adguardhome → actual → mealie → paperless → firefly → gitea → immich → matrix-synapse.

For each VM:

1. Add `system.stateVersion = lib.mkForce "25.11";` to the VM's module file.
1. Merge the PR (CI validates the new desired state).
1. On blizzard, snapshot the VM's postgresql-state volume.
1. Inside the VM, run `pg_upgrade` (see §pg_upgrade below).
1. `nixos-rebuild switch` inside the VM — PG 17 picks up the migrated data dir.
1. Start the application, run `analyze_new_cluster.sh`, smoke-test.
1. Soak ≥24 h, then clean up the old data dir.
1. Only then open the next VM's PR.

**PR Final — Collapse per-VM overrides**

- `vms/base.nix:195`: bump to `"25.11"`.
- Remove all per-VM temporary overrides.
- Result: one canonical SV declaration, zero package pins.

______________________________________________________________________

## `pg_upgrade` procedure (inside the VM)

Run *after* the VM's stateVersion-override PR is merged, *before* `nixos-rebuild switch`.

```bash
# 1. Stop application and Postgres.
APP=<service-name>
sudo systemctl stop "$APP".service
# matrix-synapse-vm: also stop matrix-authentication-service.service
sudo systemctl stop postgresql.service

# 2. Build bin dirs without switching the system.
OLDBIN=$(nix-build '<nixpkgs>' --no-out-link -A postgresql_16)/bin
NEWBIN=$(nix-build '<nixpkgs>' --no-out-link -A postgresql_17)/bin

# 3. Init new data dir.
sudo install -d -m 0700 -o postgres -g postgres /var/lib/postgresql/17
sudo -u postgres "$NEWBIN/initdb" \
  --pgdata=/var/lib/postgresql/17 --encoding=UTF8 --locale=C

# 4. Dry run first.
cd /tmp
sudo -u postgres "$NEWBIN/pg_upgrade" \
  --old-datadir=/var/lib/postgresql/16 \
  --new-datadir=/var/lib/postgresql/17 \
  --old-bindir="$OLDBIN" --new-bindir="$NEWBIN" \
  --link --check

# 5. Upgrade (only if --check passed).
sudo -u postgres "$NEWBIN/pg_upgrade" \
  --old-datadir=/var/lib/postgresql/16 \
  --new-datadir=/var/lib/postgresql/17 \
  --old-bindir="$OLDBIN" --new-bindir="$NEWBIN" \
  --link
# Expect "Upgrade Complete".

# 6. Rebuild to apply stateVersion = "25.11".
sudo nixos-rebuild switch --flake .#<vm-name>

# 7. Start and verify.
sudo systemctl start postgresql.service
sudo -u postgres psql -c 'SELECT version();'  # expect: PostgreSQL 17.x
sudo -u postgres /tmp/analyze_new_cluster.sh
sudo systemctl start "$APP".service
journalctl -u "$APP".service -f

# 8. After ≥24 h healthy, clean up.
sudo /tmp/delete_old_cluster.sh               # or: sudo rm -rf /var/lib/postgresql/16
```

### If `--check` fails

Check for incompatible extensions (`\dx` in psql) or tablespace issues. Fix in PG 16, then
re-run `--check`. Do not force past `--check` failures. If blocked, restart PostgreSQL on PG 16
(`sudo systemctl start postgresql.service`), revert the stateVersion override commit, and
re-evaluate.

______________________________________________________________________

## Breaking changes already absorbed (reference)

Because the primary `nixpkgs` tracks `nixos-unstable`, most of the 25.05/25.11 breaking
changes are already in the working tree. These items required **no further action** at
audit time (2026-05-03):

| Change | Status |
|---|---|
| `services.displayManager.*` new namespace | ✓ already used |
| `services.desktopManager.plasma6` (Qt5 removed) | ✓ already on Plasma 6 / `kdePackages.*` |
| `services.pulseaudio` (was `hardware.pulseaudio`) | ✓ already using `services.pulseaudio` |
| Flat `pkgs.gnome-*` namespace | ✓ already in use |
| `evince` / `totem` removed (→ `papers` / `showtime`) | ✓ no references in repo |
| DM VT setting dropped | ✓ no `vt =` anywhere |
| `boot.enableContainers` no longer auto-enabled | ✓ not using nspawn; using MicroVMs + quadlet |
| `switch-to-configuration` Perl removed | ✓ no `enableNg` references |
| `network-online.target` ordering | ✓ all six custom network-facing services already declare `wants`/`after`; the Synapse/MAS units only need postgres ordering (covered by `postgresql.target` swap) |
| `users.users.*.linger` default `→ null` | ✓ `linger = true` is set explicitly in both containers.nix files |
| ZFS `noauto` import change | ✓ blizzard pools do not use `noauto`; verify once after first rebuild |
| GNOME 49 X11 session removed | ✓ avalanche already on Wayland/GDM |
| ACME revamp | ✓ no NixOS-side ACME; Traefik handles its own certs |

______________________________________________________________________

## Verification quick-reference

```bash
# After PR 1 on each host:
systemctl --failed && journalctl -p3 -b
nixos-version                                   # 25.11.x or later
nix eval --raw .#nixosConfigurations.<host>.config.system.stateVersion
                                                # unchanged
tailscale status

# After each VM's Postgres upgrade:
sudo -u postgres psql -c 'SELECT version();'    # 17.x
systemctl status postgresql.service <app>.service

# After PR Final:
grep -rn "system.stateVersion" vms/             # only vms/base.nix:195
grep -rn "postgresql.package\s*=" --include="*.nix"
                                                # zero assignment lines
```
