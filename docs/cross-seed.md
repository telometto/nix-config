# cross-seed on Blizzard

cross-seed runs in a dedicated MicroVM, `cross-seed-vm` at `10.100.0.32`.
The VM is enabled on Blizzard, while `sys.services.cross-seed.enable` in
[`vms/cross-seed.nix`](../vms/cross-seed.nix) initially remains `false` so its
persistent SSH identity can be enrolled before it needs credentials.

The [upstream reference](reference-cross-seed.md) records the checked module,
version, matching behavior, and documentation sources.

## Configuration and data flow

- cross-seed reads the existing qBittorrent catalog at `10.100.0.30:11030`
  and searches selected Prowlarr Torznab indexers at `10.100.0.20:11020`.
- Both guests mount `/rpool/unenc/media/data` as `/data`. Cross-seed creates
  hardlinks under `/data/cross-seed`, with tracker subdirectories and the
  separate `cross-seed-link` client category. Its database and output torrents
  live in the persistent `cross-seed-state.img`, mounted at `/var/lib/cross-seed`.
- Flexible matching permits renamed files. Injected matches are stopped and
  fully rechecked; automatic resume permits **zero missing bytes**, including
  support files. A failed match can remain stopped in qBittorrent for review.
- RSS runs every 30 minutes; daily search batches use the upstream limit of
  400 unique queries per indexer. The daemon can start both jobs immediately
  on its first run. Searches use the existing client catalog; extra media and
  Usenet filesystem scans are disabled. Upstream's initial single-episode and
  non-video search exclusions remain in effect.
- The API listens only on `127.0.0.1:11032` inside the guest. There is no
  firewall opening, host port forward, or public publication. The host's
  network policy grants only outgoing Prowlarr and qBittorrent service access.
  The guest uses the normal bridge gateway; torrent traffic stays in qBittorrent's
  existing WireGuard path.

The initial integration uses scheduled searches. A qBittorrent completion
webhook is optional and would require a deliberate listener, guest-firewall,
and reverse network-policy change; enabling the daemon does not install one.

## Provision the guest and credentials

These are operator rollout steps; implementing this configuration does not
activate Blizzard or register secrets.

1. Build and review the Blizzard configuration and the staged guest, then apply
   the host change through the normal deployment workflow. The initial host
   update is required for the VM identity, bridge policy, and installation.
   Confirm the guest boots and `cross-seed.service` is absent.

1. From Snowfall, establish a trusted SSH connection using the guest's Ed25519
   host key. Then derive the age recipient from that verified public key in
   your local known-hosts file; guest sudo is not needed:

   ```bash
   ssh -F /dev/null -J zeno@192.168.2.100 \
     -o HostKeyAlgorithms=ssh-ed25519 admin@10.100.0.32 true
   ssh-keygen -F 10.100.0.32 | \
     awk '$2 == "ssh-ed25519" { print $2, $3 }' | \
     sort -u | nix run nixpkgs#ssh-to-age --
   ```

   Add that recipient in the private `nix-secrets` repository and re-encrypt
   the affected SOPS file with `sops updatekeys`. Only the public recipient is
   needed outside the guest. See [SOPS setup](sops-setup-guide.md).

1. Add the YAML scalar `cross-seed/settings` in the private encrypted file. Its
   value must be a JSON object shaped like this **placeholder-only** example:

   ```yaml
   cross-seed:
     settings: |
       {
         "apiKey": "REPLACE_WITH_A_RANDOM_API_KEY",
         "torrentClients": [
           "qbittorrent:http://USER:PASSWORD@10.100.0.30:11030"
         ],
         "torznab": [
           "http://10.100.0.20:11020/INDEXER_ID/api?apikey=PROWLARR_API_KEY"
         ]
       }
   ```

   Use URL-encoded username/password components and qBittorrent's existing
   authentication. Generate the cross-seed API key privately, for example
   with `openssl rand -hex 24`. Select permitted private **torrent** indexers
   explicitly, using each indexer's Prowlarr Torznab URL. Confirm their rules
   allow this use; exclude public, magnet-only, and Usenet destinations.

   Keep only the three credential-bearing keys shown above in this JSON.
   The upstream module merges it **after** declarative settings, so copying
   a full config into the secret could override the matching and resume policy.
   Never put live URLs with keys or credentials in public Nix settings.

1. Publish the private secret update through its normal workflow, then refresh
   this repository's pinned private input:

   ```bash
   nix flake update nix-secrets
   ```

   Keep the daemon disabled until the storage checks below pass. Once enabled,
   SOPS exposes the JSON at `/run/secrets/cross-seed/settings`, owned by root
   with mode `0400`. Systemd delivers a private copy through `LoadCredential`.
   Guest startup is ordered after secret installation.

## Shared filesystem policy and one-time repair

Source data and `/data/cross-seed` must be on the same filesystem, under the
same `/data` mount in both guests. Cross-seed does not remap client paths.
The persistent policy is:

- Blizzard's qBittorrent VM explicitly runs with primary group `users` (GID 100),
  private supplementary group `qbittorrent`, and umask `0002`, matching
  SABnzbd's existing pattern. Its account and private state directory retain
  the `qbittorrent` group. The reusable service module uses its configured
  `group` as the default runtime group; the shared-media override is VM-local.
- Blizzard manages the torrent root with group `users` and mode `2775`;
  the setgid bit passes that group to new directories. Existing directory
  inheritance is established by the one-time repair below.
- Cross-seed and the Arr services already have supplementary `users` access
  and group-writable creation masks. The cross-seed link directory is setgid
  and group writable.

Keep cross-seed disabled while running the following **once on Blizzard**, as
`zeno`. After it passes, enable and deploy the service together with this policy.
The repair needs host sudo only, not guest sudo.
It records the old ownership, permissions, and ACLs before updating regular
files and directories on the torrent filesystem. Permission changes also
apply to other hardlinks to the same inodes.

The 2026-11-01 host inventory found only GIDs 100 and 998, no named ACLs, and
no setgid directories in this tree. The repair is scoped to that inspected
tree, including `temp` and the existing category directories.

```bash
sudo bash <<'BASH'
set -euo pipefail
umask 077
torrents=/rpool/unenc/media/data/torrents
test -d "$torrents"
test "$(getent group users | cut -d: -f3)" = 100
backup=$(mktemp -d /var/lib/cross-seed-permissions.XXXXXXXX)
getfacl -R -P --one-file-system -p -n -- "$torrents" > "$backup/before.acl"
printf 'Permission backup: %s/before.acl\n' "$backup"

find "$torrents" -xdev \( -type d -o -type f \) ! -gid 100 \
  -exec chgrp users -- {} +
find "$torrents" -xdev -type d -exec chmod g+rwx,g+s -- {} +
find "$torrents" -xdev -type f ! -perm -0060 \
  -exec chmod g+rw -- {} +

cd /rpool/unenc/media/data
setpriv --reuid=65534 --regid=100 --clear-groups \
  find torrents -xdev -type f \( ! -readable -o ! -writable \) \
  -print > "$backup/inaccessible.paths"
if test -s "$backup/inaccessible.paths"; then
  printf 'FAIL: inspect %s/inaccessible.paths\n' "$backup" >&2
  exit 1
fi
printf 'PASS: torrent files are readable and writable through GID 100.\n'
BASH
```

Keep the printed backup path. An operator can restore the saved metadata
with `sudo setfacl --restore=/var/lib/cross-seed-permissions.XXXXXXXX/before.acl`
after reviewing later changes; restoration also restores saved group ownership.

The successful guest hardlink probe established that the VirtioFS source and
link paths share a filesystem. After deployment, verify the qBittorrent unit
uses `Group=users` and observe that subsequent downloads keep
GID 100 with group-write access. Repository checks cover the rendered service
group and persistent directory policy; they do not prove live activation.

## Enable and verify

Set `sys.services.cross-seed.enable = true` in
[`vms/cross-seed.nix`](../vms/cross-seed.nix) after the recipient, secret, and
filesystem prerequisites are ready. The initial permissions-policy rollout
requires a **Blizzard host deployment**: it installs the host directory rule
and updates qBittorrent's VM as well as cross-seed. From Snowfall, deploy the
current checkout, including the new host module:

```bash
cd "$HOME/.versioncontrol/github/projects/personal/nix-config"
NIX_SSHOPTS='-F /dev/null' nixos-rebuild switch \
  --flake "path:$PWD#blizzard" \
  --target-host zeno@192.168.2.100 \
  --ask-sudo-password
```

Later cross-seed-only changes can use the normal
[VM update workflow](../vms/README.md#vm-only-updates).

Inside the guest, verify:

```bash
systemctl status sops-install-secrets.service cross-seed.service
journalctl -u cross-seed.service --since today
curl --fail http://127.0.0.1:11032/api/ping
```

Confirm qBittorrent login and each selected Torznab connection succeed, links
resolve under `/data/cross-seed` in both guests, and matches pass a full recheck
before seeding. An incomplete candidate must stay stopped. Keep credential
values and credential-bearing log lines out of shared reports. Host/guest
builds and configuration checks do not prove this runtime acceptance.

The NixOS-generated config requires `CREDENTIALS_DIRECTORY`; ordinary
`sudo -u cross-seed cross-seed ...` commands do not have the daemon's private
credential environment. Inspect service status and use the loopback API for
routine checks. The [upstream reference](reference-cross-seed.md#runtime-preflight-without-searching)
describes the limitations of a separate, credential-aware startup preflight.

## Rotation, stopping, and retained data

Update the private JSON, refresh the pinned input, and deploy the guest to
rotate credentials. SOPS restarts `cross-seed.service` when the settings secret
changes, so its systemd credential copy is refreshed. Verify both APIs before
revoking any replaced credentials.

Stop `cross-seed.service` to stop searches and injections; set its enable flag
back to `false` for a declarative stop. Keep the guest, its state image, and
the shared links if continued seeding is wanted. Stopping cross-seed does not
stop torrents already running in qBittorrent. Hardlinked content remains
allocated while any name for it survives; removing an original download does
not remove the cross-seed hardlink. Review qBittorrent entries and shared
data separately before any cleanup.
