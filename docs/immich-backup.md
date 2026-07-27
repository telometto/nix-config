# Immich offsite backup and recovery

This runbook covers the `blizzard-immich` Borg backup in
[`hosts/blizzard/services/backup.nix`](../hosts/blizzard/services/backup.nix).
It backs up the complete Immich MicroVM state to rsync.net.

## Design and trust boundaries

The source of truth for the three backed-up images is
[`vms/immich-storage.nix`](../vms/immich-storage.nix):

| Guest mount | Image | Contents |
|-------------|-------|----------|
| `/var/lib/immich` | `immich-state.img` | Immich library and application state |
| `/var/lib/postgresql` | `postgresql-state.img` | PostgreSQL database |
| `/persist` | `persist.img` | VM identity and persistent system state |

At 03:30, the job briefly stops `microvm@immich-vm.service`, creates the
`flash/enc/vms@immich-rsyncnet` ZFS snapshot, and immediately starts the VM
again. Borg then reads the raw image files from the read-only snapshot while
Immich is online. The images are deliberately **not** loop-mounted on Blizzard:
a compromised guest must not be able to make the host kernel parse a malicious
guest filesystem.

The timer is persistent. A missed run is started after the next boot reaches
`multi-user.target` and after MicroVM autostart has settled. If the VM was
intentionally stopped, the backup fails closed and leaves it stopped.

## Provision the rsync.net repository

Use two unrelated SSH keys:

- **Backup key** — present on Blizzard and restricted to append-only Borg access
  to this repository.
- **Admin key** — kept off Blizzard and used only from a trusted recovery or
  maintenance host for initialization, checks, retention, compaction, and
  recovery.

Do not deploy the scheduled job until the restriction below has been verified.
An ordinary rsync.net SSH credential can run commands such as `rm`, so Borg
append-only mode alone is not sufficient.

1. From the trusted admin host, create `immich-borg` using the admin key:

   ```bash
   export BORG_REPO='ssh://zh6100@zh6100.rsync.net/./immich-borg'
   export BORG_RSH='ssh -i /secure/offline/rsyncnet-immich-admin -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/secure/offline/known_hosts-rsyncnet'
   export BORG_PASSCOMMAND='cat /secure/offline/immich-borg-passphrase'

   borg init --remote-path=borg14 --encryption=repokey-blake2
   borg key export --remote-path=borg14 /secure/offline/immich-borg-repokey
   ```

   Store the exported repokey and its passphrase in separate, tested recovery
   storage. The repository uses `repokey-blake2`; a passphrase without the
   encrypted repository key is not a complete disaster-recovery plan.

1. Add Blizzard's public backup key to the rsync.net account's
   `.ssh/authorized_keys` with this forced command:

   ```text
   command="borg14 serve --append-only --restrict-to-repository immich-borg",restrict ssh-ed25519 AAAA... blizzard-immich-backup
   ```

   Keep the admin public key as a separate entry. Never place its private key on
   Blizzard.

1. On Blizzard, install the root-owned backup private key as
   `/root/.ssh/immich-rsyncnet` with mode `0600` (or `0400`). Create the
   root-owned `/root/.ssh/known_hosts-rsyncnet` file with mode `0644`, `0600`,
   or `0400` after comparing the server key with rsync.net's published SSH
   fingerprints. Do not populate this file from an unauthenticated
   `ssh-keyscan` result alone.

1. Confirm the backup key cannot obtain general remote-command access:

   ```bash
   sudo ssh -T \
     -i /root/.ssh/immich-rsyncnet \
     -o BatchMode=yes \
     -o IdentitiesOnly=yes \
     -o StrictHostKeyChecking=yes \
     -o UserKnownHostsFile=/root/.ssh/known_hosts-rsyncnet \
     zh6100@zh6100.rsync.net 'echo UNRESTRICTED_SHELL'
   ```

   The literal `UNRESTRICTED_SHELL` must not be printed and the command must not
   succeed. If it does, remove the key and ask rsync.net support to confirm the
   forced-command setup before enabling backups.

The NixOS job has `doInit = false` and performs no pruning. This prevents the
Blizzard credential from being used for repository setup or routine destructive
maintenance.

## Operate and monitor the job

Inspect the schedule and run a backup:

```bash
systemctl list-timers borgbackup-job-immich-rsyncnet.timer
sudo systemctl start borgbackup-job-immich-rsyncnet.service
sudo journalctl -u borgbackup-job-immich-rsyncnet.service
```

Expected behavior:

1. The job verifies the SSH key, dedicated known-hosts file, and Borg
   passphrase file. The private key must be mode `0400` or `0600`.
1. An active Immich VM is stopped.
1. A crash-consistent ZFS snapshot of all three images is created.
1. The VM is restarted and verified active before the network upload begins.
1. Borg uploads the three raw images.
1. The temporary ZFS snapshot is destroyed.

Any VM restart or snapshot-cleanup failure fails the systemd unit and requires
operator attention. On Blizzard, `OnFailure` sends a Pushover notification
using the already provisioned Grafana Pushover credentials. Check:

```bash
systemctl status microvm@immich-vm.service
zfs list -H -t snapshot flash/enc/vms@immich-rsyncnet
journalctl -u microvm@immich-vm.service -u borgbackup-job-immich-rsyncnet.service
journalctl -u immich-backup-failure-notify.service
```

If the network or Pushover API is unavailable, the notifier failure remains in
journald; it does not conceal or reset the failed Borg unit.

Destroy a stale `flash/enc/vms@immich-rsyncnet` snapshot only after confirming
the backup unit is inactive. The next backup also removes a stale snapshot
before creating its own.

For planned Immich maintenance, stop the timer and wait for the backup unit to
be inactive before stopping the VM:

```bash
sudo systemctl stop borgbackup-job-immich-rsyncnet.timer
sudo systemctl stop borgbackup-job-immich-rsyncnet.service
systemctl is-active borgbackup-job-immich-rsyncnet.service
sudo systemctl stop microvm@immich-vm.service
```

The status command must report `inactive` (or `failed`) before the VM is
stopped. Start the timer again after maintenance. This coordination prevents an
operator stop from racing the backup's short stop-snapshot-start window.

## Retention and integrity maintenance

Run retention from the trusted admin host, never with Blizzard's backup key.
First stop the source timer and confirm the backup service is inactive. Then:

```bash
export BORG_REPO='ssh://zh6100@zh6100.rsync.net/./immich-borg'
export BORG_RSH='ssh -i /secure/offline/rsyncnet-immich-admin -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/secure/offline/known_hosts-rsyncnet'
export BORG_PASSCOMMAND='cat /secure/offline/immich-borg-passphrase'

borg check --remote-path=borg14 --verify-data
borg prune --remote-path=borg14 \
  --glob-archives 'blizzard-immich-*' \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6
borg compact --remote-path=borg14
```

Do not run admin maintenance concurrently with the scheduled job. Run `check`
before any non-append-only write so malicious or accidental damage is detected
before compaction makes it permanent.

rsync.net currently provides immutable account-level ZFS snapshots. Verify the
actual schedule and restore access for this account; provider snapshots are an
additional recovery layer, not a replacement for the append-only key or restore
drills.

## Restore Immich

Perform a restore drill after provisioning and after material storage changes.
Use a trusted recovery host with the offline admin key:

1. List archives and inspect the selected archive:

   ```bash
   export BORG_REPO='ssh://zh6100@zh6100.rsync.net/./immich-borg'
   export BORG_RSH='ssh -i /secure/offline/rsyncnet-immich-admin -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/secure/offline/known_hosts-rsyncnet'
   export BORG_PASSCOMMAND='cat /secure/offline/immich-borg-passphrase'

   borg list --remote-path=borg14
   borg list --remote-path=borg14 '::blizzard-immich-YYYY-MM-DDTHH:MM:SS'
   ```

1. Extract all three files from the same archive into an empty staging
   directory. Borg stores absolute source paths without the leading slash:

   ```bash
   archive='blizzard-immich-YYYY-MM-DDTHH:MM:SS'
   archive_path='flash/enc/vms/.zfs/snapshot/immich-rsyncnet/immich-vm'

   mkdir immich-restore
   cd immich-restore
   borg extract --remote-path=borg14 "::$archive" \
     "$archive_path/immich-state.img" \
     "$archive_path/postgresql-state.img" \
     "$archive_path/persist.img"
   ```

1. Confirm the extracted names and sizes match
   [`vms/immich-storage.nix`](../vms/immich-storage.nix), then transfer them to
   a root-owned staging directory on Blizzard. Do not loop-mount the images on
   Blizzard. If inspection is necessary, use libguestfs or a disposable,
   isolated recovery VM.

1. On Blizzard, stop the timer, backup service, and VM:

   ```bash
   sudo systemctl stop borgbackup-job-immich-rsyncnet.timer
   sudo systemctl stop borgbackup-job-immich-rsyncnet.service
   sudo systemctl stop microvm@immich-vm.service
   sudo zfs snapshot flash/enc/vms@before-immich-restore
   ```

1. Move the current three images to a dated quarantine directory. Install the
   restored `immich-state.img`, `postgresql-state.img`, and `persist.img`
   together under `/flash/enc/vms/immich-vm/` as `root:root` with mode `0600`.
   Do not mix images from different archives.

1. Start and validate Immich before re-enabling the timer:

   ```bash
   sudo systemctl start microvm@immich-vm.service
   systemctl is-active microvm@immich-vm.service
   journalctl -u microvm@immich-vm.service
   curl --fail --silent --show-error http://10.100.0.70:11070/api/server/ping
   sudo systemctl start borgbackup-job-immich-rsyncnet.timer
   ```

   Confirm login, recent assets, thumbnail access, upload, and database-backed
   metadata. Keep the quarantine directory and
   `flash/enc/vms@before-immich-restore` until the restored service has been
   accepted.

If the repository key stored with the Borg repository is unavailable, import
the offline export with `borg key import` before attempting recovery. If the
Blizzard host may have been compromised, rotate its backup SSH key after the
restore and preserve the affected repository for investigation.

## References

- [Borg `serve` restrictions](https://borgbackup.readthedocs.io/en/stable/usage/serve.html)
- [Borg append-only and compaction guidance](https://borgbackup.readthedocs.io/en/stable/usage/notes.html#append-only-mode-forbid-compaction)
- [rsync.net SSH keys](https://www.rsync.net/resources/howto/ssh_keys.html)
- [rsync.net server fingerprints](https://www.rsync.net/resources/fingerprints.txt)
- [rsync.net snapshots](https://www.rsync.net/resources/howto/snapshots.html)
- [Pushover Message API](https://pushover.net/api)
