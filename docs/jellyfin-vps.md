# Jellyfin via a Tailscale VPS

## Topology and rollout

Viewers use `https://jellyfin.<public-domain>` on a dedicated Hetzner VPS. The VPS
terminates TLS and proxies to Blizzard's Tailscale IPv4 address
(`100.85.254.99:8096`). A TCP relay bound to `tailscale0` sends the stream
to `jellyfin-vm` at `10.100.0.72:8096`; it does not create a host NAT
port-forward. Blizzard does not publish Jellyfin through its local Traefik or
Cloudflare Tunnel. When publishing the route, point the Jellyfin DNS
record at the VPS without Cloudflare's proxy. Do not forward Jellyfin ports on
the home router.

The first Blizzard configuration starts `jellyfin-vm` with Jellyfin **stopped**
and a read-only view of the host's Jellyfin state. Host Jellyfin and Plex keep
running. After the stopped-state copy, set `vmServiceReady = true` in
[`vms/jellyfin-settings.nix`](../vms/jellyfin-settings.nix) to move Jellyfin
into the VM. The Jellyfin tailnet ingress remains **closed**. After private
setup and load checks, set `vpsIPv4` in
[`vms/jellyfin-settings.nix`](../vms/jellyfin-settings.nix)
to the dedicated proxy VPS's Tailscale IPv4 address and run the public
acceptance checks below. Do not use the existing Sandfly VPS address
`100.116.146.113`;
Sandfly publishes TCP 80 and 443 and advises against other software on its
host. This migration leaves Plex and its dependent services running. The VPS,
public DNS, and tailnet policy are managed outside this repository.

On a fresh Jellyfin data directory, finish the first-run wizard and create the
administrator **privately before opening the VPS ingress or enabling the public
Caddy route**. The first visitor to an unfinished wizard could otherwise create
the administrator.
Keep the Jellyfin Caddy site disabled until private setup is complete;
see [Jellyfin setup](#jellyfin-setup) below.

This route keeps the home IP out of the ordinary viewer connection path when
clients use only the VPS hostname. Other services or DNS records can still
reveal it, and the VPS may learn Blizzard's public endpoint through Tailscale.
All media traffic traverses the VPS.

## VPS and tailnet

For Ubuntu 24.04 VPS commands, follow the [step-by-step setup guide](how-to-jellyfin-vps-ubuntu-2404.md).

Keep the dedicated VPS Tailscale identity stable. Record its IPv4 address with
`tailscale ip -4` and use it in the Blizzard firewall guard and tailnet
policy. The VM sees Blizzard's TCP relay as `10.100.0.1`, so set **Dashboard →
Networking → Known Proxies** to **only `10.100.0.1`** after migration. The VPS
address is no longer the direct Jellyfin peer. If the VPS address changes,
update the Blizzard guard and tailnet policy; verify the proxy headers again.
The current `vpsIPv4` value in `vms/jellyfin-settings.nix` is `null`
until private setup is complete; set it to the dedicated VPS address
before activating this route.

After private administrator setup, a Caddy site on the VPS can use this shape
(replace the hostname):

```caddyfile
jellyfin.example.com {
    reverse_proxy 100.85.254.99:8096
}
```

Caddy handles HTTPS, WebSockets, and the `X-Forwarded-For`,
`X-Forwarded-Proto`, and `X-Forwarded-Host` headers. Blizzard's TCP relay
passes them unchanged; Jellyfin trusts the relay's bridge address. Confirm
Caddy does not accept a viewer-supplied forwarded client IP. Do not configure
a broad `trusted_proxies` range on the VPS. Do not
enable access logging of full request URLs: Jellyfin can put API keys in query
strings. If the VPS has a global access logger, redact the URI/query and
sensitive headers there as well.

In the *complete* Tailscale policy, allow only the VPS identity to reach
Blizzard on `tcp:8096`. A grant for the VPS node's current Tailscale address
is shaped like this:

```json
{
  "src": ["<DEDICATED_VPS_TAILSCALE_IPV4>"],
  "dst": ["100.85.254.99"],
  "ip": ["tcp:8096"]
}
```

Review every existing grant and ACL that could also permit port 8096. Grants
are additive: a narrow grant does not revoke a broad one. The Blizzard host
rule blocks non-VPS sources on `tailscale0` even when Tailscale's own netfilter
chain accepts tailnet traffic, but the tailnet policy should enforce the same
identity boundary.

## Jellyfin setup

1. On Blizzard, check the host's Jellyfin version, state size, library paths,
   free space on `flash/enc/vms`, and read access to
   `/rpool/unenc/media/data/media`. The state image is 128 GiB; do not start
   the copy if the measured `/var/lib/jellyfin` contents will not fit. Preserve
   a protected local copy of the host state before changing its service.
   Jellyfin has no offsite job in this rollout.

   ```bash
   sudo du -sh /var/lib/jellyfin
   zfs list -o name,available flash/enc/vms
   sudo -u jellyfin test -r /rpool/unenc/media/data/media
   ```

1. Apply the first Blizzard configuration with `vmServiceReady = false` and
   `vpsIPv4 = null`. Confirm the host Jellyfin and Plex services remain
   active, `microvm@jellyfin-vm.service` starts, and Jellyfin is stopped in the
   VM. The VM receives the host state at `/mnt/host-jellyfin` through a
   **temporary read-only** virtiofs share. Keep the public Caddy route disabled.

1. Stop host Jellyfin for the final copy, then run this **inside the VM** as
   `admin`; `sudo` will prompt for the administrator password. First make a
   separate protected copy of the stopped host state on Blizzard:

   ```bash
   sudo systemctl stop jellyfin.service
   sudo install -d -m 0700 /flash/enc/jellyfin-host-rollback
   sudo cp -a /var/lib/jellyfin /flash/enc/jellyfin-host-rollback/
   ```

   Inside the VM, copy from the temporary read-only share:

   ```bash
   sudo rsync -aH --delete /mnt/host-jellyfin/ /var/lib/jellyfin/
   sudo chown -R jellyfin:jellyfin /var/lib/jellyfin
   sudo rsync -aHn --no-owner --no-group --delete \
     /mnt/host-jellyfin/ /var/lib/jellyfin/
   ```

   Resolve any differences and verify the copied state and owner before
   continuing. Do not remove `/var/lib/jellyfin` on Blizzard; it is the
   rollback source. If the copy fails, restart host Jellyfin and leave
   `vmServiceReady = false`.

1. Set `vmServiceReady = true` and apply the Blizzard configuration. This
   disables host Jellyfin, removes the temporary host-state share, and starts
   Jellyfin in the VM. `vpsIPv4` remains `null`; the public route is
   still blocked. From an administrator workstation, forward a local port
   through Blizzard to the VM:

   ```bash
   ssh -N -L 127.0.0.1:8097:10.100.0.72:8096 <admin>@<blizzard-ssh-host>
   ```

   Open `http://127.0.0.1:8097`. Verify the migrated administrator, users,
   libraries, and playback. If the source state was empty, complete the
   first-run wizard privately before opening the VPS route.

1. In Jellyfin, set **Known Proxies** to only `10.100.0.1` and keep **Base
   URL** empty. Check **Remote Access Settings**, **Local Networks**, and each
   user's **Allow remote connections** permission. The VM's media share is
   read-only; verify the Jellyfin user can read representative files and cannot
   write to the library. Keep metadata and artwork in the state volume.

1. Test direct play and **two simultaneous real 1080p software transcodes**
   through the private tunnel. Keep ingress closed if playback or capacity
   fails. Hardware acceleration stays disabled. The i5-10600K iGPU remains
   with Blizzard; the disabled PCI passthrough hook in
   `vms/jellyfin-settings.nix` is for a future dedicated card. Before enabling
   it, identify every PCI function and IOMMU group, verify host isolation,
   configure the guest driver and Jellyfin acceleration mode, and prove a real
   hardware transcode. Do not turn on passthrough using an unverified address.

1. With the VM stopped, take a named snapshot of `flash/enc/vms` before
   publication and restart it. The following commands run on Blizzard; choose
   a new snapshot name if one already exists:

   ```bash
   sudo systemctl stop microvm@jellyfin-vm.service
   sudo zfs snapshot flash/enc/vms@jellyfin-pre-public
   sudo systemctl start microvm@jellyfin-vm.service
   sudo install -d -m 0700 /flash/enc/jellyfin-restore-check
   sudo cp --sparse=always -a \
     /flash/enc/vms/.zfs/snapshot/jellyfin-pre-public/jellyfin-vm/jellyfin-state.img \
     /flash/enc/vms/.zfs/snapshot/jellyfin-pre-public/jellyfin-vm/persist.img \
     /flash/enc/jellyfin-restore-check/
   sudo e2fsck -fn /flash/enc/jellyfin-restore-check/jellyfin-state.img
   sudo e2fsck -fn /flash/enc/jellyfin-restore-check/persist.img
   sudo debugfs -R 'ls -l /' /flash/enc/jellyfin-restore-check/jellyfin-state.img
   sudo debugfs -R 'ls -l /' /flash/enc/jellyfin-restore-check/persist.img
   ```

   This rehearses recovery into a staging directory using copies of the
   stopped images. Verify that the state image contains the expected Jellyfin
   database and configuration files and that the persist image contains the
   guest's SSH identity. Resolve filesystem errors before publishing; retain
   the snapshot until the live VM has been tested again, then remove the
   scratch copies when no longer needed. The separate cache image is
   disposable. Confirm Sanoid's existing recursive
   `flash` policy is creating local snapshots of `flash/enc/vms`; this
   rollout adds no offsite Jellyfin backup.

## Acceptance before VPS publication

After applying the Blizzard configuration, check the host rules and their
packet counters on Blizzard:

```bash
sudo iptables -t raw -C PREROUTING -i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096 -j JELLYFIN_VPS
sudo iptables -t raw -vnL JELLYFIN_VPS
sudo ip6tables -t raw -C PREROUTING -i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096 -j DROP
sudo ss -ltn '( sport = :8096 )'
sudo systemctl status jellyfin-vps-relay.socket
```

A firewall reload briefly blocks this ingress while rebuilding the owned
`JELLYFIN_VPS` chain. If the reload logs `Jellyfin VPS ingress remains blocked`,
inspect `sudo iptables -t raw -S JELLYFIN_VPS`, resolve the unexpected rule, and
reload the firewall again. The direct DROP remains until a successful rebuild.

- From the VPS, reach `http://100.85.254.99:8096` over Tailscale. From a
  different tailnet peer, port 8096 must be denied. Check both IPv4 and IPv6.
- Confirm the relay is bound only to `tailscale0`, the guest accepts port
  `8096` only from `10.100.0.1`, and an attempted write to the media share
  fails. Check the guest cannot open undeclared connections to other MicroVMs.
- From outside the home network, confirm `https://jellyfin.<public-domain>`
  resolves to the VPS only and supports login, WebSockets, seek, direct play,
  and two simultaneous real 1080p software transcodes. Confirm the VPS can
  sustain the required throughput and transfer volume.
- Confirm home public IPv4 and IPv6 do not accept Jellyfin on 8096/8920 or
  discovery traffic on UDP 1900/7359. Plex remains enabled with
  `openFirewall = true`, which opens UDP 1900 on Blizzard's host firewall.
  Denial of public UDP 1900 therefore depends on the router and IPv6 edge;
  verify both externally or close Plex discovery separately. Review router
  forwarding and DNS records.
- Verify Jellyfin sees the client IP and enforces remote-access and user
  permissions through the proxy. Send a spoofed `X-Forwarded-For` header from
  a test client and verify it cannot change the recorded client IP. Check that
  proxy logs do not include API keys.
- Leave Plex, Overseerr, Tautulli, and Subgen running. The host's original
  `/var/lib/jellyfin` and the stopped-VM snapshot are the rollback sources.
  To return to host Jellyfin, close the VPS route, set
  `vmServiceReady = false`, apply the host configuration, and verify the
  original host administrator login. VM changes made after migration will not
  be in the preserved host state.

## References

- [Jellyfin: first-run administrator wizard](https://jellyfin.org/docs/general/post-install/setup-wizard/)
- [Jellyfin: Tailscale and remote reverse proxy](https://jellyfin.org/docs/general/post-install/networking/tailscale/)
- [Jellyfin: reverse proxy, Known Proxies, WebSockets, and logging](https://jellyfin.org/docs/general/post-install/networking/reverse-proxy/)
- [Jellyfin: remote access and Base URL](https://jellyfin.org/docs/general/post-install/networking/)
- [Caddy: reverse proxy defaults](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Tailscale: grants syntax and additive permissions](https://tailscale.com/docs/reference/syntax/grants)
- [Tailscale: netfilter modes](https://tailscale.com/docs/reference/netfilter-modes)
- [Sandfly: running on non-default ports and host isolation](https://docs.sandflysecurity.com/docs/run-sandfly-on-non-default-ports)
