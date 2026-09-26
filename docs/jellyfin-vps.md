# Jellyfin via a Tailscale VPS

## Topology and rollout

Viewers use `https://jellyfin.<public-domain>` on a Hetzner VPS. The VPS
terminates TLS and proxies to Blizzard's Tailscale IPv4 address
(`100.85.254.99:8096`). Blizzard does not publish Jellyfin through its local
Traefik or Cloudflare Tunnel. Keep the Jellyfin DNS record pointed at the VPS
without Cloudflare's proxy, and do not forward Jellyfin ports on the home router.

The Blizzard configuration starts Jellyfin alongside Plex for migration checks
and limits its tailnet ingress to VPS peer `100.116.146.113`. Plex and its
dependent services can be removed after the acceptance checks below. The VPS,
public DNS, and tailnet policy are managed outside this repository.

This route keeps the home IP out of the ordinary viewer connection path when
clients use only the VPS hostname. Other services or DNS records can still
reveal it, and the VPS may learn Blizzard's public endpoint through Tailscale.
All media traffic traverses the VPS.

## VPS and tailnet

Keep the VPS Tailscale identity stable. Its IPv4 address is
`100.116.146.113`; add exactly this address in Jellyfin's **Dashboard →
Networking → Known Proxies**. If it changes, update both the Blizzard firewall
rule and Known Proxies before serving clients. Do not add other tailnet
addresses or CIDR ranges to Known Proxies.

A Caddy site on the VPS can use this shape (replace the hostname):

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
  "src": ["100.116.146.113"],
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

1. Confirm `/var/lib/jellyfin` is backed up before importing users and libraries.
   The NixOS module creates persistent data and cache directories; this repo's
   existing offsite jobs do not include Jellyfin state.
1. Set **Known Proxies** to `100.116.146.113`. Keep **Base URL**
   empty; the public site uses a dedicated hostname rather than `/jellyfin`.
1. Check **Remote Access Settings**, **Local Networks**, and each user's
   **Allow remote connections** permission. Verify that public clients are
   recorded with their actual client IP, not the VPS address or a spoofed
   `X-Forwarded-For` value.
1. Add libraries under `/rpool/unenc/media/data/media` only after confirming
   that the `jellyfin` service account can traverse the parent directories and
   read sample media files. Keep the library read-only unless a specific
   feature requires writes.
1. The existing GPU helper installs Intel packages and adds Jellyfin to
   `video` and `render`; it does not choose a render device or enable NixOS
   Jellyfin hardware acceleration. Inspect `/dev/dri` and the actual GPU,
   select the corresponding `services.jellyfin.hardwareAcceleration` type and
   device, then prove a transcoding session in Jellyfin's dashboard. Do not
   infer acceleration from the service starting successfully.

## Acceptance before Plex cutover

After applying the Blizzard configuration, check the host rules and their
packet counters on Blizzard:

```bash
sudo iptables -t raw -C PREROUTING -i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096 -j JELLYFIN_VPS
sudo iptables -t raw -vnL JELLYFIN_VPS
sudo ip6tables -t raw -C PREROUTING -i tailscale0 -m addrtype --dst-type LOCAL -p tcp --dport 8096 -j DROP
sudo ss -ltn '( sport = :8096 )'
```

- From the VPS, reach `http://100.85.254.99:8096` over Tailscale. From a
  different tailnet peer, port 8096 must be denied. Check both IPv4 and IPv6.
- From outside the home network, confirm `https://jellyfin.<public-domain>`
  resolves to the VPS only and supports login, WebSockets, seek, direct play,
  and a real transcoded stream. Confirm the VPS can sustain the required
  throughput and transfer volume.
- Confirm home public IPv4 and IPv6 do not accept Jellyfin on 8096/8920 or
  discovery traffic on UDP 1900/7359. Review router forwarding and DNS records.
- Verify Jellyfin sees the client IP and enforces remote-access and user
  permissions through the proxy. Check that proxy logs do not include API keys.
- Restore-test Jellyfin state backup, then plan migration of Plex-specific
  integrations, including Overseerr, Tautulli, and Subgen, before disabling
  Plex. Keep rollback available until clients and integrations pass.

## References

- [Jellyfin: Tailscale and remote reverse proxy](https://jellyfin.org/docs/general/post-install/networking/tailscale/)
- [Jellyfin: reverse proxy, Known Proxies, WebSockets, and logging](https://jellyfin.org/docs/general/post-install/networking/reverse-proxy/)
- [Jellyfin: remote access and Base URL](https://jellyfin.org/docs/general/post-install/networking/)
- [Caddy: reverse proxy defaults](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Tailscale: grants syntax and additive permissions](https://tailscale.com/docs/reference/syntax/grants)
- [Tailscale: netfilter modes](https://tailscale.com/docs/reference/netfilter-modes)
