# cross-seed on Blizzard

cross-seed runs in a dedicated MicroVM, `cross-seed-vm` at `10.100.0.32`.
The checked-in Blizzard configuration enables both the VM and the daemon through
`sys.services.cross-seed.enable = true` in
[`vms/cross-seed.nix`](../vms/cross-seed.nix). This describes the source configuration;
it does not establish live guest readiness. Fresh or replacement guests need the
explicit disabled bootstrap below before their first deployment.

The [upstream reference](reference-cross-seed.md) records the checked module,
version, matching behavior, and documentation sources.

## Configuration and data flow

- cross-seed reads the existing qBittorrent catalog at `10.100.0.30:11030`
  and searches selected Prowlarr Torznab indexers at `10.100.0.20:11020`.
- Both guests mount `/rpool/unenc/media/data` as `/data`. Cross-seed creates
  hardlinks under `/data/cross-seed`, with tracker subdirectories and the
  separate `cross-seed-link` client category. Its database and output torrents
  live in the persistent `cross-seed-state.img`, mounted at `/var/lib/cross-seed`.
  This guest rejects `sys.services.cross-seed.dataDir` overrides: changing the
  state path requires an explicit migration of the persistent image layout.
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

1. **Before deploying a fresh or replacement guest**, set
   `sys.services.cross-seed.enable = false` in
   [`vms/cross-seed.nix`](../vms/cross-seed.nix). Keep the VM instance enabled.
   This omits both `cross-seed.service` and its SOPS secret while the guest's
   persistent SSH identity is being enrolled. Do not deploy the checked-in
   enabled daemon to an unenrolled guest: it requires the secret and can begin
   searches and injections as soon as its credentials work.

1. Build and review the Blizzard configuration and the disabled guest, then apply
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
`zeno`. Reserve a maintenance window and quiesce **every process that can write
or rename entries in the torrent tree**, including host jobs, interactive
sessions, containers, and any writable NFS/SMB clients. Inspect the running
system for additional writers; the VM list below covers the repository's
writable VirtioFS shares, not every possible live export or host process.

Record which of these VMs are running and any pre-existing masks, then stop and runtime-mask the whole
guests from the host. Stopping only their normal application services leaves
other guest processes able to replace pathnames during the root repair.
Lidarr is included even though its instance is currently disabled.

```bash
systemctl list-units --all 'microvm@*-vm.service'
sudo systemctl mask --runtime --now \
  microvm@{cross-seed,qbittorrent,sonarr,radarr,readarr,lidarr,bazarr,sabnzbd}-vm.service
```

Keep all writers stopped from **before the metadata backup through repair,
verification, and installation of the new host/guest group policy**. Do not
reboot during this window: runtime masks disappear on reboot. Leave masks in
place if any step fails. Resume only through the deployment sequence below;
repeating traversals while writers are active cannot establish a stable result.
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
export PATH=/run/current-system/sw/bin
for name in cross-seed qbittorrent sonarr radarr readarr lidarr bazarr sabnzbd; do
  unit="microvm@${name}-vm.service"
  test "$(systemctl show --property=LoadState --value "$unit")" = masked
  case "$(systemctl show --property=ActiveState --value "$unit")" in
    inactive|failed) ;;
    *) printf 'FAIL: writer guest %s is not stopped.\n' "$unit" >&2; exit 1 ;;
  esac
done
torrents=/rpool/unenc/media/data/torrents
test -d "$torrents"
test "$(getent group users | cut -d: -f3)" = 100
backup=$(mktemp -d /var/lib/cross-seed-permissions.XXXXXXXX)
getfacl -R -P --one-file-system -p -n -- "$torrents" > "$backup/before.acl"
printf 'Permission backup: %s/before.acl\n' "$backup"

find "$torrents" -xdev \( -type d -o -type f \) ! -gid 100 \
  -execdir chgrp --no-dereference users -- {} +
find "$torrents" -xdev -type d -execdir chmod --no-dereference g+rwx,g+s -- {} +
find "$torrents" -xdev -type f ! -perm -0060 \
  -execdir chmod --no-dereference g+rw -- {} +

find "$torrents" -xdev \
  \( -type d \( ! -gid 100 -o ! -perm -2070 \) \
  -o -type f \( ! -gid 100 -o ! -perm -0060 \) \) \
  -print > "$backup/incorrect-metadata.paths"
if test -s "$backup/incorrect-metadata.paths"; then
  printf 'FAIL: inspect %s/incorrect-metadata.paths\n' "$backup" >&2
  exit 1
fi

cd /rpool/unenc/media/data
setpriv --reuid=65534 --regid=100 --clear-groups \
  find torrents -xdev \
  \( -type d \( ! -readable -o ! -writable -o ! -executable \) \
  -o -type f \( ! -readable -o ! -writable \) \) \
  -print > "$backup/inaccessible.paths"
if test -s "$backup/inaccessible.paths"; then
  printf 'FAIL: inspect %s/inaccessible.paths\n' "$backup" >&2
  exit 1
fi
printf 'PASS: directory inheritance and file access satisfy the GID 100 policy.\n'
BASH
```

The fixed absolute `PATH`, `-execdir`, and non-dereferencing commands add path
protection; they do not replace the all-writers-stopped prerequisite. The
verification checks directory group, group access, and setgid inheritance as
well as file group/access, including traversal by a non-owner GID-100 process.

Keep the printed backup path. An operator can restore the saved metadata
with `sudo setfacl --restore=/var/lib/cross-seed-permissions.XXXXXXXX/before.acl`
after reviewing later changes. Restoration also resolves saved pathnames and
restores group ownership: quiesce all writers for the entire restore and
verification, too. Keep the writer guests masked until the restored state and
the intended runtime group policy have been reconciled.

The successful guest hardlink probe established that the VirtioFS source and
link paths share a filesystem. After deployment, verify the qBittorrent unit
uses `Group=users` and observe that subsequent downloads keep
GID 100 with group-write access. Repository checks cover the rendered service
group and persistent directory policy; they do not prove live activation.

## Enable and verify

After fresh provisioning, or the one-time permission repair, set
`sys.services.cross-seed.enable = true` in
[`vms/cross-seed.nix`](../vms/cross-seed.nix) after the recipient, secret, and
filesystem prerequisites are ready. The initial permissions-policy rollout
requires a **Blizzard host deployment**: it installs the host directory rule
and updates qBittorrent's VM as well as cross-seed. From Snowfall, deploy the
current checkout, including the new host module. If performing the permission
repair, keep every writer stopped and the VM runtime masks in place during
this deployment. Record the expected runner paths from this exact checkout
before deploying:

```bash
cd "$HOME/.versioncontrol/github/projects/personal/nix-config"
nix eval --raw .#nixosConfigurations.qbittorrent-vm.config.microvm.declaredRunner.outPath
nix eval --raw .#nixosConfigurations.cross-seed-vm.config.microvm.declaredRunner.outPath
NIX_SSHOPTS='-F /dev/null' nixos-rebuild switch \
  --flake "path:$PWD#blizzard" \
  --target-host zeno@192.168.2.100 \
  --ask-sudo-password
```

With runtime-masked guests, activation can report failed attempts to start those
units. Keep the masks and inspect any deployment errors before resuming; a masked
guest must not cause the old qBittorrent runner to be restarted. Confirm the
new host configuration and updated guest runners have been installed, then
follow the maintenance restart checks below before unmasking writers.

For the permission maintenance, run these checks **on Blizzard**, with every
writer still quiesced. Restarting these installer units installs the new
host-declared runners without starting the masked VMs:

```bash
sudo systemctl daemon-reload
sudo systemctl restart \
  install-microvm-qbittorrent-vm.service \
  install-microvm-cross-seed-vm.service
systemctl show -p ActiveState -p SubState -p Result \
  install-microvm-qbittorrent-vm.service \
  install-microvm-cross-seed-vm.service
readlink -f /flash/enc/vms/qbittorrent-vm/current
readlink -f /flash/enc/vms/cross-seed-vm/current

qb_runner=$(readlink -f /flash/enc/vms/qbittorrent-vm/current)
qb_unit="$qb_runner/share/microvm/system/etc/systemd/system/qbittorrent.service"
grep -Fx 'Group=users' "$qb_unit"
grep -Fx 'SupplementaryGroups=qbittorrent' "$qb_unit"
grep -Fx 'UMask=002' "$qb_unit"
```

Require both installers to report `active` / `exited` / `success`, both installed
runner paths to equal the recorded paths, and all three unit checks to pass.
If any check fails, leave the masks in place and resolve it before resuming.
Only then remove this maintenance's qBittorrent mask and start its new runner:

```bash
sudo systemctl unmask --runtime microvm@qbittorrent-vm.service
sudo systemctl start microvm@qbittorrent-vm.service
```

Inside qBittorrent's guest, confirm `systemctl show qbittorrent.service -p Group`
reports `users` and representative new files/directories retain GID 100,
group-write access, and directory setgid inheritance. Then remove the remaining
masks created for this maintenance, restart only the other previously running
writer VMs, and resume the quiesced host jobs/clients. Preserve any pre-existing
masks and leave disabled instances stopped. Finally unmask/start
`microvm@cross-seed-vm.service` when its credentials and storage are ready;
do not enable searches before that gate.

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
