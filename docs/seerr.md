# Migrate Overseerr to Seerr

Seerr replaces the archived Overseerr application. Upstream runs the
[configuration and database migration](https://docs.seerr.dev/migration-guide/)
automatically on first start. Back up the stopped instance before deploying;
rolling the executable back alone does not undo database migrations.

## Storage and networking

The infrastructure keeps the `overseerr` name so the existing VM directory,
disk, runner, and host network policy remain in use:

| Setting | Value |
|---|---|
| Flake output / host unit | `overseerr-vm` / `microvm@overseerr-vm.service` |
| Host VM directory | `/flash/enc/vms/overseerr-vm` |
| State image | `overseerr-state.img` (10 GiB) |
| Guest config directory | `/var/lib/overseerr` |
| Guest application unit / account | `seerr.service` / `seerr:seerr` |
| Backend | `10.100.0.40:11040` |
| Public hostname | `requests.<canonical-domain>` |

The existing Sonarr and Radarr peer permissions and Plex-compatible Traefik
policy are retained. This change does not configure a different media-server
integration; review those settings in Seerr after migration.

The VM explicitly sets `services.seerr.configDir` and the unit's
`StateDirectory`, avoiding the upstream NixOS module's default state path.
It uses a static system account because `DynamicUser` relocates state under
`/var/lib/private`, which conflicts with the mounted image. Systemd prepares
the directory and its ownership before starting Seerr; no separate tmpfiles
rule preempts that ownership migration.

## Back up and deploy

Run these commands on Blizzard from a checkout containing the migration.
Build before stopping the VM, with the SSH access needed by `nix-secrets`:

```bash
nix build .#nixosConfigurations.blizzard.config.system.build.toplevel --no-link
nix build .#checks.x86_64-linux.seerr .#checks.x86_64-linux.microvm-publication --no-link
```

Create a backup directory on encrypted storage. Check free space for a full
10 GiB image if reflinks are unavailable. Stop the VM before copying so the
SQLite database, journal files, and `settings.json` form a consistent backup,
as required by the [upstream backup guidance](https://docs.seerr.dev/using-seerr/backups/).

```bash
sudo install -d -m 0700 /flash/enc/vm-migration-backups
backup_dir=$(sudo mktemp -d /flash/enc/vm-migration-backups/overseerr-XXXXXXXX)
sudo systemctl stop microvm@overseerr-vm.service
sudo cp --sparse=always --preserve=all --reflink=auto \
  /flash/enc/vms/overseerr-vm/overseerr-state.img "$backup_dir/overseerr-state.img"
sudo cmp /flash/enc/vms/overseerr-vm/overseerr-state.img "$backup_dir/overseerr-state.img"
printf 'Backup directory: %s\n' "$backup_dir"
```

Proceed only after the copy and comparison succeed. Keep the backup path
outside the guest, and do not remove the backup after the initial login.

When ready to apply the configuration:

```bash
sudo nixos-rebuild switch --flake .#blizzard
sudo systemctl start microvm@overseerr-vm.service
```

The host installs the new runner and starts the guest. Seerr then performs
its application migration. The state image and VM directory must keep their
existing names. VM-only updates are also supported through the repository's
[normal update workflow](../vms/README.md#vm-only-updates), after the change is
available at the configured update reference; take the same stopped backup
before the first Seerr start.

## Verify

Inside `overseerr-vm`, inspect `systemctl status seerr.service` and
`journalctl -u seerr.service -b` for successful startup and migration. Check
`curl --fail http://127.0.0.1:11040/api/v1/status` for an HTTP success response.

Open the existing `requests.<canonical-domain>` URL and verify existing users,
requests, notification settings, and Sonarr/Radarr integrations. Test a media
request and Plex sign-in. A fresh setup wizard or missing history indicates
that the expected data was not read; stop the VM and investigate the backup,
mount, and config directory before continuing.

## Roll back

Stop the VM before restoring any state. Restore the entire pre-migration
image, including settings and the database, rather than running Overseerr
against Seerr's migrated database. Retain the failed image separately if it
is needed for investigation.

For an immediate rollback after the host-switch deployment above, with no
intervening host generations:

```bash
sudo systemctl stop microvm@overseerr-vm.service &&
  sudo cp --sparse=always --preserve=all --reflink=auto \
    "$backup_dir/overseerr-state.img" /flash/enc/vms/overseerr-vm/overseerr-state.img &&
  sudo cmp "$backup_dir/overseerr-state.img" /flash/enc/vms/overseerr-vm/overseerr-state.img &&
  sudo nixos-rebuild switch --rollback &&
  sudo systemctl start microvm@overseerr-vm.service
```

Run the block as one command chain. The `&&` operators stop the sequence at
the first failure. If stopping fails, resolve the error before restoring
state. If the copy or comparison fails, keep the VM stopped and resolve the
error before retrying; do not roll back the host or start the guest.

If using a later shell, set `backup_dir` to the recorded backup path first.
If the guest was updated independently, select its pre-migration runner
instead of assuming that a host-generation rollback restores it. Verify the
restored application and data before resuming requests.
