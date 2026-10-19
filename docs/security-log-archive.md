# Security-log archive: R-02 retention

The implementation is **disabled on Blizzard and Snowfall**. It is ready for
source review and isolated validation. Provisioning, capacity acceptance, live
delivery, recovery, and notification acceptance remain deployment gates. Do not
close R-02: its HTTP attribution/remediation acceptance and auditd execution
capture remain separate work.

## Contract and readable data

Blizzard's journal reader normalizes selected records into immutable JSONL
segments under `/var/lib/security-log-archive/ready`. Each segment has a v1 header
with cursor boundaries, sequence, SHA-256, counters and seal time. A SQLite
transaction registers the segment and its journal cursor only after the file
and directory are synced. Startup adopts a seal left between these two steps.
Committed remote acknowledgements precede local deletion. Replays are allowed;
record IDs derive from host plus journal cursor and support recovery deduplication.

The two-minute uploader stages at most 128 MiB, commits a restic snapshot, verifies
its manifest, then acknowledges those exact segments. A fresh segment takes
priority during backlog recovery. Every batch includes event-time bounds and
configuration revision, NixOS/restic versions, and a flake-lock hash. The previous
snapshot ID is saved explicitly to avoid automatic parent discovery on later
uploads. There is no exactly-once or post-compromise authenticity guarantee.

| Source | Archived content |
|---|---|
| Traefik | Client socket/chain, host, method, path, status, timing, sizes and User-Agent |
| CrowdSec | Allowlisted alert/remediation metadata and remediation-log loss reports |
| OpenSSH | Trusted journal metadata; parsed accepted/failed authentication details |
| Tailscale SSH | Journal metadata for `ssh-conn-` messages; its free-form payload is omitted |
| sudo | Actor, target user, TTY, executable without command arguments, session state |
| Kernel | Selected AppArmor denial fields and existing `microvm-policy` message fields |

Query strings, fragments, authorization headers, cookies, bodies, arbitrary
producer fields and raw-message passthrough are excluded. Paths, User-Agent,
addresses and usernames still contain personal or sensitive text. Unknown
selected messages retain metadata only and are counted for schema review.
No new kernel logging or firewall policy is enabled.

`security-log-reader` can read the entire system journal through
`systemd-journal`; source selection is an application boundary. It has no network
access or service credentials. `security-log-uploader` shares the spool group,
receives the upload SSH key, restic password and heartbeat URL through systemd
credentials, and has no journal-reader group. The shared spool is mode `2770`,
segments/database are group-readable and writable, and numeric textfile metrics
are readable by node exporter. Both accounts can modify the shared local queue;
server-side preservation protects records already delivered.

The repository password is on Blizzard, so root can decrypt prior archives.
Its upload SSH identity cannot overwrite/delete committed repository objects or
obtain a shell. The separate administrative SSH identity lives on Snowfall and
in tested independent recovery storage. Neither identity protects future source
records or heartbeat signals from an attacker controlling Blizzard.

## Capacity and failure behavior

- Retain every uploaded batch for at least **365 days**; do not thin records to
  daily/weekly representative snapshots.
- Deliver new records within **five minutes** in healthy operation: seal every
  30 seconds, upload every two minutes, and bound the upload service to 60 seconds.
  Confirm this with real marked records and observed upload durations.
- Target **72 hours** of interrupted delivery within a **20 GiB** spool budget.
  The budget reserves space for staging and metadata; actual usable queue space
  is smaller. The target depends on measured normalized volume.
- Pause collection at the spool budget or the **5 GiB filesystem free-space
  floor**. Keep unsent segments and the last durable cursor. Host services
  continue; source journal rotation may cause a recorded gap before recovery.
- Journal storage becomes persistent when enabled. Inspect and record the
  effective journal size/time/rate limits; they remain independently bounded
  and do not guarantee 72 hours of history after collection has paused.
- A missing cursor produces a gap record and replays the oldest available
  matching entries. Loss before journaling, including bouncer queue loss, cannot
  be recovered by this archive.
- Preserve incomplete/failed uploads locally. Restic exit code 3 is failure,
  even if it produced a partial snapshot. A heartbeat failure does not undo a
  successful archive acknowledgement.

Before activation, run a representative read-only sizing pass on Blizzard:

```bash
nix build .#packages.x86_64-linux.security-log-archive --no-link
# Use the built CLI and the evaluated clientConfigFile; output is counts/bytes only.
security-log-archive --config /path/to/public-client-config.json size --since '7 days ago'
journalctl --disk-usage
systemd-analyze cat-config systemd/journald.conf
df -B1 /var/lib/security-log-archive
```

Confirm that the journal interval actually exists. Include normal traffic and
bursts. Normalize/compress representative data and account for **262,800
snapshots/year**, tree/index overhead, and provider snapshots. Require projected
annual growth plus **25% allowance** to fit while leaving **20% of total account
quota free**, after existing use. Also verify local 72-hour capacity and upload
completion below 60 seconds at expected batch sizes. If the existing quota
cannot satisfy this, leave the feature disabled and report the capacity blocker;
do not shorten retention or expand paid capacity automatically.

A disposable local metadata benchmark is available:

```bash
python3 tests/security_log_archive_scale.py --target /tmp/security-archive-scale --snapshots 100
# Full year-count exercise is intentionally explicit and potentially expensive:
python3 tests/security_log_archive_scale.py --target /tmp/security-archive-year --snapshots 262800
```

The report distinguishes measured snapshot count from extrapolation. Local
results do not prove rsync.net throughput or production capacity. The observed
year-count performance remains a pre-activation acceptance requirement.
Restic's private index cache under the upload directory is additional disposable
disk usage; include its measured growth in filesystem sizing and the free-space
reserve. It contains no independent recovery credential.

## Provision independently, then enable

1. From Snowfall or a trusted recovery environment, create a separate restic v2
   repository at `blizzard-security-logs` on the existing rsync.net account over
   SFTP. Record its ID from `restic cat config`. Verify the account's server-side
   rclone supports append-only rejection of both overwrites and deletion.

1. Generate unrelated upload/admin SSH identities. Force the upload public key
   to this command in rsync.net `authorized_keys`, preserving other entries:

   ```text
   restrict,command="rclone serve restic --stdio --append-only blizzard-security-logs" ssh-ed25519 PUBLIC_UPLOAD_KEY
   ```

1. Keep the admin private key off Blizzard. Using disposable records and the
   upload identity, prove that existing snapshot/object overwrite, deletion,
   other-repository access, SFTP and general command execution fail. These are
   provider acceptance tests; local fixture results do not establish them.

1. Verify the published rsync.net SSH fingerprint independently. Provision
   `/etc/ssh/security-log-archive-known-hosts` on both hosts. Do not trust an
   unauthenticated `ssh-keyscan` result alone.

1. In the private `nix-secrets` input, provision these root-owned `0400` secrets:

   | Host | Secret keys |
   |---|---|
   | Blizzard | `security-log-archive/upload-ssh`, `security-log-archive/password`, `security-log-archive/heartbeat-url` |
   | Snowfall | `security-log-archive/admin-ssh`, `security-log-archive/password` |

   Secret values never belong in this repository. Save an independent recovery
   bundle containing the admin identity, repository password/ID/location, verified
   host key, and compatible restic tooling; recovery must not depend on Blizzard
   or its SOPS state. Prove the bundle before enabling uploads.

1. Create one Healthchecks.io check with **period 5 minutes**, **grace 5 minutes**,
   and Pushover down/recovery notifications. Keep account management credentials
   off Blizzard. Its secret is only `https://hc-ping.com/<uuid>`; empty success
   POSTs follow verified fresh commits. No logs are sent to Healthchecks. Use the
   existing free allowance, and verify actual notification delivery/resolution.
   Also configure independent rsync.net account-capacity notifications at 80%
   and 90% usage. The restricted upload identity cannot query the entire account
   quota, so local upload success is not a remote free-space measurement.

1. Set the same recorded `repositoryId` on both hosts. Enable collection on
   Blizzard and `admin.enable` on Snowfall after the capacity/provider/recovery
   gates pass. Keep admin enablement off Blizzard. Review the effective units,
   limits, secret paths and journal configuration before separately authorized
   activation.

rsync.net documents the [append-only restic transport](https://www.rsync.net/resources/notes/2025-q4-rsync.net_technotes.html).
Restic describes its [encryption and append-only trust boundaries](https://restic.readthedocs.io/en/stable/100_references.html).
Healthchecks describes [period and grace behavior](https://healthchecks.io/docs/configuring_checks/).

## Operate, restore, and maintain from Snowfall

Inspect local units and numeric metrics on Blizzard:

```bash
systemctl status security-log-archive-collector security-log-archive-upload
systemctl list-timers security-log-archive-upload.timer
cat /var/lib/prometheus-node-exporter/security-log-archive/archive.prom
```

Grafana rules cover missing/stale collection, delivery/backlog age, buffer
pressure, pauses, recent loss reports and unsupported schemas. A loss alert
can resolve after its ten-minute notification window; the historical gap and
counter remain. Healthchecks provides a separate missed-upload signal while
Blizzard or its network is unavailable. Neither proves honest reporting after
a source compromise.

On Snowfall, administrative commands require access to the root-only credentials:

```bash
sudo security-log-archive-admin inspect
sudo security-log-archive-admin restore \
  --since 2026-10-19T00:00:00Z --until 2026-10-20T00:00:00Z \
  --target /secure/recovery/security-logs-2026-10-19
```

The recovery target must be new or empty. Recovery selects encrypted snapshots
by their event-time tags, verifies restic data and segment SHA-256 values, and
exports stable-ID-deduplicated `events.jsonl`. Preserve the recovered manifests
and snapshots as evidence. Exercise this with Blizzard offline and the
independent bundle, not just the routinely installed Snowfall credentials.
Conflicting contents for the same event ID abort export; incomplete exports keep
the `.partial` suffix. To recover known-good evidence despite unrelated malformed
or forged snapshots, repeat `--snapshot <full-id>` for the selected original IDs.

Retention is manual and based on Snowfall's current UTC time. It retains every
snapshot inside the last 365 days; extra injected snapshots cannot displace valid
ones. Unexpected host/profile, future timestamps, mismatched repository IDs, or
a preview older than 15 minutes abort maintenance. A suspected source compromise
requires containment and upload-key revocation before any destructive maintenance.

```bash
sudo security-log-archive-admin retention-preview --plan /secure/retention-preview.json
# Inspect the concrete ID list and cutoff before applying it.
# On Blizzard, stop the timer, wait for/stop the current upload, then stop collection.
# Verify no client is writing before continuing on Snowfall.
sudo security-log-archive-admin retention-apply \
  --plan /secure/retention-preview.json --uploads-paused
```

Apply first runs a full integrity check and a sample restore, then forgets only
the explicit expired IDs and prunes. The acknowledgement flag is an operator
attestation; the CLI does not remotely stop Blizzard. Resume collection and its
timer afterward, then verify catch-up and notification recovery. Avoid
`--keep-last`, daily/weekly thinning, or cutoffs relative to the newest snapshot.
See [restic's append-only retention guidance](https://restic.readthedocs.io/en/stable/060_forget.html#security-considerations-in-append-only-mode).

## Validation, acceptance, and rollback

```bash
python3 tests/security_log_archive_test.py
python3 -m unittest discover -s .github/tests -p 'test_flake_ci.py'
nix build .#checks.x86_64-linux.security-log-archive --no-link
nix build .#checks.x86_64-linux.security-log-archive-runtime --no-link
```

The first check includes real restic/rclone protocol and offline recovery tests
and Prometheus rule tests. The two-VM fixture exercises journal capture, distinct
service users, forced-command SSH, rejected snapshot deletion, network failure,
reboot survival, and recovery with the source stopped. Fixtures use disposable
credentials and do not contact real storage or monitoring accounts.

After authorized activation, record configuration revision, lock hash, deployed
generation, versions, UTC intervals and outcomes for marked HTTP/SSH/sudo events,
five-minute independent retrieval, reboot, interrupted delivery, gap/capacity
behavior, and Pushover firing/resolution. Add provider restrictions, capacity
and year-count benchmark evidence. Source/build/fixture proof alone cannot close
these gates. Initial collection replays at most 24 hours of available history;
it does not migrate the existing VictoriaLogs history.

For rollback, stop collection/upload and disable their host options through the
normal approved deployment path. Preserve the local spool, repository and
recovery bundle. Do not reset the cursor or prune evidence to clear an alert.
