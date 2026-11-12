# Set up the Jellyfin proxy on an Ubuntu 24.04 VPS

Use a dedicated VPS for this proxy. The existing Sandfly VPS publishes TCP 80
and 443 from its `sandfly-server` container, and Sandfly advises against
running other software on the same host. Running Caddy in Docker there would
still conflict with those published ports. Do not change Sandfly's port mappings
for this Jellyfin setup. If Caddy was enabled there and failed to bind, run
`sudo systemctl disable caddy` on the Sandfly host to prevent a boot-time race.

This guide assumes Tailscale is connected on the new VPS. Replace
`jellyfin.example.com` with your public hostname. Viewers connect to the new
VPS; Caddy forwards requests over Tailscale to Blizzard at
`100.85.254.99:8096`.

**Before opening the VPS ingress or creating a public Caddy route**, activate
Jellyfin in `jellyfin-vm` with `vpsIPv4 = null` in
`vms/jellyfin-settings.nix` and finish its first-run administrator wizard
privately. From an administrator workstation, run
`ssh -N -L 127.0.0.1:8097:10.100.0.72:8096 <admin>@<blizzard-ssh-host>` and
open `http://127.0.0.1:8097`. Create a strong administrator password and verify
login through the tunnel. If the guest state volume already contains Jellyfin
data, inspect it before treating this as a new server. Keep the public Jellyfin
Caddy site disabled until setup is complete; an unfinished wizard exposed
publicly can be claimed by a visitor.

1. **Check the new VPS.** Confirm TCP 80 and 443 are available before installing
   Caddy:

   ```bash
   sudo ss -ltnp '( sport = :80 or sport = :443 )'
   ```

   If another service owns either port, identify it before continuing. Caddy
   must be the service accepting public HTTP and HTTPS on this VPS.

1. **Set DNS and public ingress.** Create an A record for the hostname pointing
   to the VPS public IPv4 address. Add an AAAA record only if the VPS serves
   IPv6. If using Cloudflare DNS, set the record to **DNS only**. Allow inbound
   TCP 80 and 443 from any client IPv4 address, and from any IPv6 address if
   serving IPv6, in the Hetzner Cloud Firewall. Preserve the SSH access rule;
   do not expose TCP 8096 publicly. Leave outbound rules empty unless outbound
   filtering is intentional. Check UFW's status:

   ```bash
   sudo ufw status
   ```

   If UFW is active, also run:

   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

   There is no need to enable an inactive UFW for this guide. Test a new SSH
   connection after applying the Hetzner firewall; an existing session may
   remain connected even if new connections are blocked.

1. **Record the dedicated VPS Tailscale address.** Run:

   ```bash
   tailscale ip -4
   ```

   Inspect `vpsIPv4` in
   [`vms/jellyfin-settings.nix`](../vms/jellyfin-settings.nix). Before private
   setup, explicitly set it to `null` and apply that configuration to close
   this VPS ingress path. After private setup, set it to the dedicated VPS
   address and apply the Blizzard configuration for this route. Do not use
   `100.116.146.113`, the **Sandfly** VPS address. Use the private SSH tunnel
   to set Jellyfin **Dashboard → Networking → Known Proxies** to `10.100.0.1`,
   the Blizzard relay's address as seen by the VM. Keep **Base URL** empty for
   this dedicated hostname.
   In the Tailscale admin console, add this object to the existing `grants`
   array, substituting the new address; do not replace the rest of the policy:

   ```json
   {
     "src": ["<DEDICATED_VPS_TAILSCALE_IPV4>"],
     "dst": ["100.85.254.99"],
     "ip": ["tcp:8096"]
   }
   ```

   Review existing grants and ACLs for broader access to TCP 8096. A narrow
   grant does not revoke an existing broad one.

1. **Install Caddy** from its official stable Ubuntu package repository:

   ```bash
   (
     set -eu
     sudo apt update
     sudo apt install -y ca-certificates curl gnupg
     caddy_setup=$(mktemp -d)
     trap 'rm -rf -- "$caddy_setup"' EXIT
     curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key -o "$caddy_setup/key"
     printf '%s  %s\n' '783dfee04b19e851a928cd87b34710213ebbe7628f98d9f34595ab83be578c00' "$caddy_setup/key" | sha256sum --check
     mkdir -m 0700 "$caddy_setup/gnupg"
     GNUPGHOME="$caddy_setup/gnupg" gpg --batch --dearmor -o "$caddy_setup/keyring.gpg" "$caddy_setup/key"
     sudo install -m 0644 "$caddy_setup/keyring.gpg" /usr/share/keyrings/caddy-stable-archive-keyring.gpg
     printf '%s\n' 'deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
     sudo apt update
     sudo apt install -y caddy
   )
   ```

If the signing-key check fails, stop and review the upstream key rotation before
updating the pinned hash. Do not download and trust replacement source-list policy.

1. **Publish after private administrator login works.** Open
   `/etc/caddy/Caddyfile` with
   `sudo nano /etc/caddy/Caddyfile`. Replace the package's example site with
   the block below. If the VPS already hosts other sites, keep those blocks and
   add this one:

   ```caddyfile
   jellyfin.example.com {
       reverse_proxy 100.85.254.99:8096
   }
   ```

   Caddy obtains HTTPS certificates and supports WebSockets and forwarded
   headers automatically. Avoid logging full request URLs: Jellyfin may include
   API keys in query strings. Check any existing global access logger too.

   ```bash
   sudo caddy validate --config /etc/caddy/Caddyfile # Check the configuration.
   sudo systemctl reload caddy                      # Apply it without stopping Caddy.
   sudo systemctl status caddy                      # Check that Caddy is running.
   ```

1. **Verify after VPS ingress is enabled on Blizzard.** On the VPS, test the
   Tailscale upstream:

   ```bash
   curl --connect-timeout 5 -I http://100.85.254.99:8096/
   ```

   From another network, open `https://jellyfin.example.com` and test login
   and playback. The upstream test will fail while `vpsIPv4 = null`; set it to
   the dedicated VPS Tailscale IPv4 only after private setup, then activate
   Blizzard's updated configuration. Check public IPv4 and IPv6 reachability of
   Blizzard separately: Plex still opens UDP 1900 on the host, so public denial
   of that discovery port depends on the router and IPv6 edge.

For the full rollout and acceptance checks, see [Jellyfin via a Tailscale VPS](jellyfin-vps.md).

## Sources

- [Caddy installation](https://caddyserver.com/docs/install)
- [Caddy systemd service](https://caddyserver.com/docs/running#using-the-service)
- [Caddy reverse proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Ubuntu UFW](https://documentation.ubuntu.com/server/how-to/security/firewalls/index.html)
- [Cloudflare DNS-only records](https://developers.cloudflare.com/dns/proxy-status/)
- [Jellyfin reverse proxy and Known Proxies](https://jellyfin.org/docs/general/post-install/networking/reverse-proxy/)
- [Jellyfin first-run setup wizard](https://jellyfin.org/docs/general/post-install/setup-wizard/)
- [Tailscale grants](https://tailscale.com/docs/reference/syntax/grants)
- [Sandfly: running on non-default ports and host isolation](https://docs.sandflysecurity.com/docs/run-sandfly-on-non-default-ports)
- [Hetzner Cloud Firewall defaults](https://docs.hetzner.com/cloud/firewalls/faq/)
