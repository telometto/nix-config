# Matrix offsite backup and recovery

> Status: the backup job and this runbook are declarative source wiring. Private
> key/passphrase provisioning, repository verification, and the isolated restore
> gate must pass before relying on the timer or enabling the bridge.

This runbook covers the `blizzard-matrix` Borg job in
[`hosts/blizzard/services/backup.nix`](../hosts/blizzard/services/backup.nix).
It backs up the Matrix MicroVM's stopped-VM image directory to a separate
rsync.net repository. The bridge remains disabled by default, but its
`mautrix-whatsapp-state.img` is included automatically when that image exists.

## State and trust boundaries

[`vms/matrix-storage.nix`](../vms/matrix-storage.nix) is the authoritative
baseline inventory, with the bridge image recorded as an optional backup
volume:

| Guest mount | Image | Contents |
| --- | --- | --- |
| `/var/lib/matrix-synapse` | `matrix-synapse-state.img` | Synapse state and media metadata |
| `/var/lib/postgresql` | `postgresql-state.img` | Synapse, MAS, and bridge databases |
| `/var/lib/mas` | `mas-state.img` | MAS state |
| `/persist` | `persist.img` | VM identity and persistent system state |
| `/var/lib/mautrix-whatsapp` (when enabled) | `mautrix-whatsapp-state.img` | WhatsApp linked-device and crypto state |

The backup job stops `microvm@matrix-synapse-vm.service`, creates the
`flash/enc/vms@matrix-synapse-rsyncnet` snapshot, verifies the four baseline
images, and starts the VM before Borg reads the snapshot. Borg receives the
whole read-only `matrix-synapse-vm` directory so an enabled
`mautrix-whatsapp-state.img` is included in the same snapshot. The job never
loop-mounts guest filesystems on Blizzard.

The timer runs daily at 04:30, after Immich's 03:30 job. A stopped Matrix VM is
not started by the backup: the job fails closed and leaves it stopped. A failed
stop, restart, snapshot, image check, upload, or cleanup requires operator
attention.

## Provision the separate repository

Use credentials unrelated to the Immich backup:

- backup SSH key on Blizzard: `/root/.ssh/matrix-rsyncnet`;
- root-owned pinned host keys: `/root/.ssh/known_hosts-rsyncnet`;
- SOPS passphrase secret: `matrix-backup/borg-passphrase`; and
- an offline Borg repository-key export and admin SSH key.

The private `nix-secrets` flake must contain the passphrase under the exact
secret name above. Do not put its value, the private SSH key, or the Borg key
export in this repository. The Matrix passphrase must not be the Immich
`general/borgKeyFilePath` value.

From a trusted admin host, initialize `matrix-borg`:

```bash
export BORG_REPO='ssh://zh6100@zh6100.rsync.net/./matrix-borg'
export BORG_RSH='ssh -i /secure/offline/rsyncnet-matrix-admin -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/secure/offline/known_hosts-rsyncnet'
export BORG_PASSCOMMAND='cat /secure/offline/matrix-borg-passphrase'

borg init --remote-path=borg14 --encryption=repokey-blake2
borg key export --remote-path=borg14 /secure/offline/matrix-borg-repokey
```

Add Blizzard's public backup key to the rsync.net account with an append-only
forced command restricted to this repository:

```text
command="borg14 serve --append-only --restrict-to-repository matrix-borg",restrict ssh-ed25519 AAAA... blizzard-matrix-backup
```

Keep the admin key off Blizzard. Install only the root-owned backup key on
Blizzard with mode `0400` or `0600`, and install the root-owned
`known_hosts-rsyncnet` file with mode `0400`, `0600`, or `0644` after verifying
the provider's published SSH fingerprint. Do not trust an unauthenticated
`ssh-keyscan` result alone.

Before enabling or relying on the timer, verify that the backup key cannot run
an unrestricted command:

```bash
sudo ssh -T \
  -i /root/.ssh/matrix-rsyncnet \
  -o BatchMode=yes \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile=/root/.ssh/known_hosts-rsyncnet \
  zh6100@zh6100.rsync.net 'echo UNRESTRICTED_SHELL'
```

The command must not succeed or print `UNRESTRICTED_SHELL`. The NixOS job uses
`doInit = false` and performs no pruning or compaction with Blizzard's key.

## Operate and verify

```bash
systemctl list-timers borgbackup-job-matrix-rsyncnet.timer
sudo systemctl start borgbackup-job-matrix-rsyncnet.service
sudo journalctl -u borgbackup-job-matrix-rsyncnet.service
```

Confirm the following after the first successful run:

1. The repository preflight passed before the VM was stopped.
2. The VM returned to `active` before the upload began.
3. The archive contains the four baseline images from one snapshot. When the
   bridge is enabled, it also contains `mautrix-whatsapp-state.img`.
4. The temporary snapshot was removed.

Useful checks are:

```bash
systemctl status microvm@matrix-synapse-vm.service
zfs list -H -t snapshot flash/enc/vms@matrix-synapse-rsyncnet
journalctl -u microvm@matrix-synapse-vm.service -u borgbackup-job-matrix-rsyncnet.service
```

For planned Matrix maintenance, stop the timer and wait for the backup service
to become inactive before stopping the VM. Do not destroy a snapshot while the
backup service is still active.

## Retention and integrity maintenance

Run repository maintenance from the trusted admin host, never with Blizzard's
append-only key:

```bash
export BORG_REPO='ssh://zh6100@zh6100.rsync.net/./matrix-borg'
export BORG_RSH='ssh -i /secure/offline/rsyncnet-matrix-admin -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/secure/offline/known_hosts-rsyncnet'
export BORG_PASSCOMMAND='cat /secure/offline/matrix-borg-passphrase'

borg check --remote-path=borg14 --verify-data
borg prune --remote-path=borg14 \
  --glob-archives 'blizzard-matrix-*' \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6
borg compact --remote-path=borg14
```

Export and retain the repository key with the passphrase in separate tested
recovery storage. Provider snapshots are an additional recovery layer, not a
replacement for the forced-command key or restore rehearsal.

## Isolated restore gate

An archive listing is not proof of recovery. Perform the first restore on a
trusted recovery host into an empty staging directory or disposable MicroVM
environment. Do not loop-mount the restored images on Blizzard and do not copy
them into the production state directory for this drill.

```bash
export BORG_REPO='ssh://zh6100@zh6100.rsync.net/./matrix-borg'
export BORG_RSH='ssh -i /secure/offline/rsyncnet-matrix-admin -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/secure/offline/known_hosts-rsyncnet'
export BORG_PASSCOMMAND='cat /secure/offline/matrix-borg-passphrase'

archive='blizzard-matrix-YYYY-MM-DDTHH:MM:SS'
mkdir matrix-restore
cd matrix-restore
borg list --remote-path=borg14 "::$archive"
borg extract --remote-path=borg14 "::$archive" \
  'flash/enc/vms/.zfs/snapshot/matrix-synapse-rsyncnet/matrix-synapse-vm'
```

Inspect the extracted tree with `borg list` evidence and confirm that all
baseline image names and expected sizes match `matrix-storage.nix`. If the
bridge was enabled for the selected archive, confirm its state image is from
the same archive. Start the restored VM only with production publication,
production DNS, federation, and outbound peer access disabled or redirected.

The isolated rehearsal must verify PostgreSQL, Synapse, MAS, local
administrative access, existing password login, representative rooms/media,
encryption keys, and the persisted SSH identity. With the bridge enabled, also
verify database initialization, registration regeneration, linked-device state,
and the documented QR/pairing re-login procedure if linked-device state is not
restored. Record the archive, date, duration, operator, result, and manual
steps. Repeat after a material storage/backup-format change and at least every
six months.

If the repository key is unavailable, import the offline export before
recovery. If Blizzard may have been compromised, rotate its Matrix backup SSH
key after the incident and preserve the affected repository for investigation.
