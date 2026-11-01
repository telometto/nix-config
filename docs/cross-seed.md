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

1. Log into the guest as `admin`. Derive its public age recipient from the
   persistent SSH host key:

   ```bash
   sudo ssh-keygen -y -f /persist/ssh/ssh_host_ed25519_key | nix run nixpkgs#ssh-to-age --
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

## Check the shared filesystem before enabling

Source data and `/data/cross-seed` must be on the same filesystem, under the
same `/data` mount in both guests. Cross-seed does not remap client paths.
Do not add a separate mount for the link directory. Both services belong to
the `users` group; the link directory is setgid and group writable, and newly
created links/directories use umask `0002`.

Existing files need inspection as well. A read-only Blizzard sample on
2026-11-01 found a movie file with mode `0664` whose group was not `users`;
that sample is a provisioning concern, not proof of access from the new guest.
Linux's protected-hardlink policy generally requires source ownership or both
read and write access. Readability alone is insufficient. Review ownership and
ACLs across the intended source directories and arrange compatible access
before starting searches; do not recursively change the media tree blindly.

The staged guest creates the service account and link directory even with the
daemon disabled. Before enabling it, test a representative existing file from
each source directory as `cross-seed`:

```bash
sudo -u cross-seed test -r /data/torrents/REPLACE_WITH_EXISTING_FILE
sudo -u cross-seed test -w /data/torrents/REPLACE_WITH_EXISTING_FILE
sudo -u cross-seed ln /data/torrents/REPLACE_WITH_EXISTING_FILE /data/cross-seed/.permission-check
stat -c '%d:%i %h %n' /data/torrents/REPLACE_WITH_EXISTING_FILE /data/cross-seed/.permission-check
```

The device and inode must match. Confirm qBittorrent can read the link at the
same path, then remove only this temporary link. This preserves the original
file. A single probe does not prove access to every existing torrent.

## Enable and verify

Set `sys.services.cross-seed.enable = true` in
[`vms/cross-seed.nix`](../vms/cross-seed.nix) after the recipient, secret, and
filesystem prerequisites are ready. Build and deploy the guest through the
normal [VM update workflow](../vms/README.md#vm-only-updates). A VM-only update
is sufficient after the initial Blizzard host wiring is deployed.

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
