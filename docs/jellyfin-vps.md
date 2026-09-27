# Jellyfin via a Tailscale VPS

## Topology and rollout

Viewers use `https://jellyfin.<public-domain>` on a dedicated Hetzner VPS. The VPS
terminates TLS and proxies to Blizzard's Tailscale IPv4 address
(`100.85.254.99:8096`). Blizzard does not publish Jellyfin through its local
Traefik or Cloudflare Tunnel. When publishing the route, point the Jellyfin DNS
record at the VPS without Cloudflare's proxy. Do not forward Jellyfin ports on
the home router.

The Blizzard configuration starts Jellyfin alongside Plex for migration checks,
but the Jellyfin tailnet ingress starts **closed**. Provision a dedicated proxy
VPS, then set `jellyfinVpsIPv4` in
[`hosts/blizzard/services/media.nix`](../hosts/blizzard/services/media.nix)
to its Tailscale IPv4 address only after private administrator setup. Then run
the acceptance checks below. Do not use the existing Sandfly VPS address
`100.116.146.113`;
Sandfly publishes TCP 80 and 443 and advises against other software on its
host. Plex and its dependent services can be removed after the acceptance
checks below. The VPS, public DNS, and tailnet policy are managed outside this
repository.

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
`tailscale ip -4` and add exactly that address in Jellyfin's **Dashboard →
Networking → Known Proxies**. If it changes, update both the Blizzard firewall
rule and Known Proxies before serving clients. Do not add other tailnet
addresses or CIDR ranges to Known Proxies. The current address in
[`hosts/blizzard/services/media.nix`](../hosts/blizzard/services/media.nix)
is `null` until private setup is complete; set it to the dedicated VPS address
before activating this route.

After private administrator setup, a Caddy site on the VPS can use this shape
(replace the hostname):

```caddyfile
jellyfin.example.com {
    reverse_proxy 100.85.254.99:8096
}
```

Caddy handles HTTPS, WebSockets, and the `X-Forwarded-For`,
`X-Forwarded-Proto`, and `X-Forwarded-Host` headers for this direct-client
topology. Do not configure a broad `trusted_proxies` range on the VPS. Do not
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

1. Apply the Blizzard configuration while `jellyfinVpsIPv4 = null` and with
   **no public Jellyfin proxy route**. This starts Jellyfin for local setup but
   denies its tailnet ingress. Verify any existing proxy or port forward is not
   publishing port 8096. From an administrator workstation, forward a local
   port over SSH to Blizzard (replace the SSH destination):

   ```bash
   ssh -N -L 127.0.0.1:8097:127.0.0.1:8096 <admin>@<blizzard-ssh-host>
   ```

   Open `http://127.0.0.1:8097` locally. On a fresh data directory, finish
   Jellyfin's setup wizard, choose a strong administrator password, and verify
   that the new administrator can log in through this private tunnel. On an
   existing installation, verify an administrator login instead. Keep the
   tunnel for the remaining private setup steps. Set the dedicated peer address
   and publish the Caddy route only after these steps are complete.

1. Confirm `/var/lib/jellyfin` is backed up before importing users and libraries.
   The NixOS module creates persistent data and cache directories; this repo's
   existing offsite jobs do not include Jellyfin state.

1. Set **Known Proxies** to the dedicated VPS Tailscale IPv4 address. Keep
   **Base URL** empty; the public site uses a dedicated hostname rather than
   `/jellyfin`.

1. Check **Remote Access Settings**, **Local Networks**, and each user's
   **Allow remote connections** permission. After publishing, verify that
   public clients are recorded with their actual client IP, not the VPS address
   or a spoofed `X-Forwarded-For` value.

1. Add libraries under `/rpool/unenc/media/data/media` only after confirming
   that the `jellyfin` service account can traverse the parent directories and
   read sample media files. Keep the library read-only unless a specific
   feature requires writes.

1. The existing GPU helper installs Intel packages and adds Jellyfin to
   `video` and `render`; it does not enable acceleration. Inspect `/dev/dri`
   and the actual GPU. If Jellyfin has never started, set
   `services.jellyfin.hardwareAcceleration.enable = true` plus its matching
   `type` and `device` **before the first start**. If `encoding.xml` already
   exists, configure acceleration in Jellyfin's **Dashboard → Playback →
   Transcoding** instead: the pinned NixOS default
   `services.jellyfin.forceEncodingConfig = false` leaves that file alone on
   later starts. To make Nix authoritative for an existing file, set
   `forceEncodingConfig = true` only after reviewing its settings; NixOS backs
   it up and overwrites dashboard transcoding changes on every service start.
   Prove acceleration with a real transcoding session in the dashboard.

## Acceptance before Plex cutover

After applying the Blizzard configuration, check the host rules and their
packet counters on Blizzard:

```bash
sudo iptables -t raw -C PREROUTING -i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096 -j JELLYFIN_VPS
sudo iptables -t raw -vnL JELLYFIN_VPS
sudo ip6tables -t raw -C PREROUTING -i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096 -j DROP
sudo ss -ltn '( sport = :8096 )'
```

A firewall reload briefly blocks this ingress while rebuilding the owned
`JELLYFIN_VPS` chain. If the reload logs `Jellyfin VPS ingress remains blocked`,
inspect `sudo iptables -t raw -S JELLYFIN_VPS`, resolve the unexpected rule, and
reload the firewall again. The direct DROP remains until a successful rebuild.

- From the VPS, reach `http://100.85.254.99:8096` over Tailscale. From a
  different tailnet peer, port 8096 must be denied. Check both IPv4 and IPv6.
- From outside the home network, confirm `https://jellyfin.<public-domain>`
  resolves to the VPS only and supports login, WebSockets, seek, direct play,
  and a real transcoded stream. Confirm the VPS can sustain the required
  throughput and transfer volume.
- Confirm home public IPv4 and IPv6 do not accept Jellyfin on 8096/8920 or
  discovery traffic on UDP 1900/7359. Plex remains enabled with
  `openFirewall = true`, which opens UDP 1900 on Blizzard's host firewall.
  Denial of public UDP 1900 therefore depends on the router and IPv6 edge;
  verify both externally or close Plex discovery separately. Review router
  forwarding and DNS records.
- Verify Jellyfin sees the client IP and enforces remote-access and user
  permissions through the proxy. Check that proxy logs do not include API keys.
- Restore-test Jellyfin state backup, then plan migration of Plex-specific
  integrations, including Overseerr, Tautulli, and Subgen, before disabling
  Plex. Keep rollback available until clients and integrations pass.

## References

- [Jellyfin: first-run administrator wizard](https://jellyfin.org/docs/general/post-install/setup-wizard/)
- [Jellyfin: Tailscale and remote reverse proxy](https://jellyfin.org/docs/general/post-install/networking/tailscale/)
- [Jellyfin: reverse proxy, Known Proxies, WebSockets, and logging](https://jellyfin.org/docs/general/post-install/networking/reverse-proxy/)
- [Jellyfin: remote access and Base URL](https://jellyfin.org/docs/general/post-install/networking/)
- [Caddy: reverse proxy defaults](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Tailscale: grants syntax and additive permissions](https://tailscale.com/docs/reference/syntax/grants)
- [Tailscale: netfilter modes](https://tailscale.com/docs/reference/netfilter-modes)
- [Sandfly: running on non-default ports and host isolation](https://docs.sandflysecurity.com/docs/run-sandfly-on-non-default-ports)
