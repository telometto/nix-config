## Service Modules

`sys.services.*` is the option namespace for all self-hosted services. Modules
live in `modules/services/` and are auto-loaded by
[system-loader.nix](../../system-loader.nix) — no manual imports needed.

### Module pattern

```nix
{ lib, config, ... }:
let cfg = config.sys.services.<name>; in
{
  options.sys.services.<name>.enable = lib.mkEnableOption "...";
  config = lib.mkIf cfg.enable { ... };
}
```

Most modules expose additional options (port, openFirewall, data directory,
secrets references, etc.) alongside the mandatory `enable` flag.

---

### Service catalog

#### Media — PVR / Arr stack

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [sonarr.nix](sonarr.nix) | `sys.services.sonarr` | MicroVM | TV show PVR |
| [radarr.nix](radarr.nix) | `sys.services.radarr` | MicroVM | Movie PVR |
| [prowlarr.nix](prowlarr.nix) | `sys.services.prowlarr` | MicroVM | Indexer aggregator |
| [bazarr.nix](bazarr.nix) | `sys.services.bazarr` | MicroVM | Subtitle management |
| [readarr.nix](readarr.nix) | `sys.services.readarr` | MicroVM | Books PVR |
| [lidarr.nix](lidarr.nix) | `sys.services.lidarr` | MicroVM | Music PVR |
| [qbittorrent.nix](qbittorrent.nix) | `sys.services.qbittorrent` | MicroVM (WG-routed) | Torrent client |
| [sabnzbd.nix](sabnzbd.nix) | `sys.services.sabnzbd` | MicroVM (WG-routed) | Usenet client |
| [ombi.nix](ombi.nix) | `sys.services.ombi` | MicroVM | Media request portal (legacy) |
| [overseerr.nix](overseerr.nix) | `sys.services.overseerr` | MicroVM | Media request portal |
| [tautulli.nix](tautulli.nix) | `sys.services.tautulli` | MicroVM | Plex statistics |
| [jellyfin.nix](jellyfin.nix) | `sys.services.jellyfin` | Host (blizzard) | Open-source media server |
| [plex.nix](plex.nix) | `sys.services.plex` | Host (blizzard) | Plex media server |

#### Finance and Productivity

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [firefly.nix](firefly.nix) | `sys.services.firefly` | MicroVM | Firefly III personal finance |
| [actual.nix](actual.nix) | `sys.services.actual` | MicroVM | Actual Budget (personal finance) |
| [paperless.nix](paperless.nix) | `sys.services.paperless` | MicroVM | Document management |
| [protonmail-bridge.nix](protonmail-bridge.nix) | `sys.services.protonmailBridge` | Host | Proton Mail IMAP/SMTP bridge |
| [glance.nix](glance.nix) | `sys.services.glance` | MicroVM | Self-hosted dashboard |

#### Identity and Matrix

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [matrix-synapse.nix](matrix-synapse.nix) | `sys.services.matrixSynapse` | MicroVM | Matrix homeserver |
| [matrix-authentication-service.nix](matrix-authentication-service.nix) | `sys.services.matrixAuthenticationService` | MicroVM | OIDC provider for Matrix |

#### Observability

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [grafana.nix](grafana.nix) | `sys.services.grafana` | Host (blizzard) | Dashboards and alerting |
| [grafana-cloud.nix](grafana-cloud.nix) | `sys.services.grafanaCloud` | Host | Grafana Cloud remote-write config |
| [grafana-pushover.nix](grafana-pushover.nix) | `sys.services.grafanaPushover` | Host | Pushover alert contact point |
| [prometheus.nix](prometheus.nix) | `sys.services.prometheus` | Host (blizzard) | Metrics collection |
| [prometheus-exporters.nix](prometheus-exporters.nix) | `sys.services.prometheusExporters` | Host + VMs | System metrics exporters |
| [victoriametrics.nix](victoriametrics.nix) | `sys.services.victoriametrics` | Host (blizzard) | Long-term time-series storage |
| [victoriametrics-remote-write.nix](victoriametrics-remote-write.nix) | `sys.services.victoriametricsRemoteWrite` | Host | Remote-write forwarding |
| [arr-exporter.nix](arr-exporter.nix) | `sys.services.arrExporter` | MicroVM | Prometheus exporter for Arr stack |
| [electricity-price-exporter.nix](electricity-price-exporter.nix) | `sys.services.electricityPriceExporter` | Host | Nord Pool electricity price exporter |
| [scrutiny.nix](scrutiny.nix) | `sys.services.scrutiny` | Host (blizzard) | Disk health monitoring (S.M.A.R.T.) |

#### Infrastructure and Reverse Proxy

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [traefik.nix](traefik.nix) | `sys.services.traefik` | Host (blizzard) | Reverse proxy and TLS termination |
| [cloudflared.nix](cloudflared.nix) | `sys.services.cloudflared` | Host (blizzard) | Cloudflare Tunnel daemon |
| [cloudflare-access-ip-updater.nix](cloudflare-access-ip-updater.nix) | `sys.services.cloudflareAccessIpUpdater` | Host | Updates Cloudflare Access IP lists |
| [crowdsec.nix](crowdsec.nix) | `sys.services.crowdsec` | Host (blizzard) | Collaborative intrusion detection |

#### Network and DNS

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [adguardhome.nix](adguardhome.nix) | `sys.services.adguardhome` | MicroVM | DNS sinkhole / ad blocker |
| [tailscale.nix](tailscale.nix) | `sys.services.tailscale` | Host + VMs | Mesh VPN |
| [wireguard.nix](wireguard.nix) | `sys.services.wireguard` | MicroVM | WireGuard VPN gateway |
| [resolved.nix](resolved.nix) | `sys.services.resolved` | Host + VMs | systemd-resolved DNS stub |
| [nfs.nix](nfs.nix) | `sys.services.nfs` | Host (blizzard) | NFS server/client |
| [samba.nix](samba.nix) | `sys.services.samba` | Host (blizzard) | SMB/Windows file sharing |

#### Storage

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [zfs.nix](zfs.nix) | `sys.services.zfs` | Host (blizzard) | ZFS pool management |
| [sanoid.nix](sanoid.nix) | `sys.services.sanoid` | Host (blizzard) | ZFS snapshot policies |
| [seaweedfs.nix](seaweedfs.nix) | `sys.services.seaweedfs` | Host | Distributed object storage |

#### Security and Backup

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [borgbackup.nix](borgbackup.nix) | `sys.services.borgbackup` | Host + VMs | Deduplicating off-site backup |
| [ups.nix](ups.nix) | `sys.services.ups` | Host (blizzard) | UPS monitoring (NUT) |

#### System

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [openssh.nix](openssh.nix) | `sys.services.openssh` | Host + VMs | SSH server |
| [maintenance.nix](maintenance.nix) | `sys.services.maintenance` | Host + VMs | Periodic cleanup tasks |
| [auto-upgrade.nix](auto-upgrade.nix) | `sys.services.autoUpgrade` | Servers | Automatic flake upgrades |
| [timesyncd.nix](timesyncd.nix) | `sys.services.timesyncd` | Host + VMs | NTP via systemd-timesyncd |
| [flatpak.nix](flatpak.nix) | `sys.services.flatpak` | Desktops | Flatpak application sandbox |
| [pipewire.nix](pipewire.nix) | `sys.services.pipewire` | Desktops | PipeWire audio/video |
| [printing.nix](printing.nix) | `sys.services.printing` | Desktops | CUPS printing |
| [cockpit.nix](cockpit.nix) | `sys.services.cockpit` | Host (blizzard) | Web-based admin console |
| [teamviewer.nix](teamviewer.nix) | `sys.services.teamviewer` | Desktops | Remote desktop access |

#### Containerized Browsers and Search

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [searx.nix](searx.nix) | `sys.services.searx` | MicroVM | SearXNG meta-search engine |
| [flaresolverr.nix](flaresolverr.nix) | `sys.services.flaresolverr` | MicroVM | Cloudflare bypass for indexers |
| [brave.nix](brave.nix) | `sys.services.brave` | MicroVM (WG-routed) | Containerized Brave browser |
| [firefox.nix](firefox.nix) | `sys.services.firefox` | MicroVM (WG-routed) | Containerized Firefox browser |

#### Photo Management

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [immich.nix](immich.nix) | `sys.services.immich` | MicroVM | Self-hosted photo library |

#### Git Forge

| Module file | Option prefix | Typical location | Purpose |
|-------------|--------------|-----------------|---------|
| [gitea.nix](gitea.nix) | `sys.services.gitea` | MicroVM | Self-hosted Git forge |

---

### MicroVM deployment note

Most Arr-stack, search, finance, Matrix, Paperless, Gitea, and Immich services
run inside MicroVMs rather than directly on the host. The service module in
`modules/services/` defines the NixOS options and configuration; the VM
definition in `vms/<name>.nix` imports the module and wires it into the MicroVM
network.

See [vms/README.md](../../vms/README.md) for the full VM inventory, IP
addressing, network topology, and deployment details.

---

### Related

- [Grafana dashboards library](../../lib/grafana-dashboards.nix)
- [Traefik helper library](../../lib/traefik.nix)
- [Custom dashboards](../../dashboards/)
