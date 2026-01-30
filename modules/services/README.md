## Service Modules

Self-hosted service configurations with consistent option interfaces.

### Available Services

| Service | Module | Description | Default Port |
|---------|--------|-------------|--------------|
| **Monitoring** |
| Grafana | [grafana.nix](grafana.nix) | Visualization and dashboarding | 3000 |
| Prometheus | [prometheus.nix](prometheus.nix) | Metrics collection | 9090 |
| VictoriaMetrics | [victoriametrics.nix](victoriametrics.nix) | Time-series database | 8428 |
| Prometheus Exporters | [prometheus-exporters.nix](prometheus-exporters.nix) | System metrics exporters | Various |
| **Media** |
| Jellyfin | [jellyfin.nix](jellyfin.nix) | Media server | 8096 |
| Plex | [plex.nix](plex.nix) | Media server | 32400 |
| Tautulli | [tautulli.nix](tautulli.nix) | Plex monitoring | 8181 |
| Ombi | [ombi.nix](ombi.nix) | Media requests | 5000 |
| **Storage & Backup** |
| NFS | [nfs.nix](nfs.nix) | Network file sharing | 2049 |
| Samba | [samba.nix](samba.nix) | Windows file sharing | 445 |
| BorgBackup | [borgbackup.nix](borgbackup.nix) | Deduplicating backup | — |
| Sanoid | [sanoid.nix](sanoid.nix) | ZFS snapshot management | — |
| Scrutiny | [scrutiny.nix](scrutiny.nix) | Disk health monitoring | 8080 |
| **Networking** |
| Tailscale | [tailscale.nix](tailscale.nix) | Mesh VPN | — |
| Cloudflared | [cloudflared.nix](cloudflared.nix) | Cloudflare tunnel | — |
| AdGuard Home | [adguardhome.nix](adguardhome.nix) | DNS filtering | 3000 |
| **Security** |
| CrowdSec | [crowdsec.nix](crowdsec.nix) | Security automation | 8080 |
| OpenSSH | [openssh.nix](openssh.nix) | SSH server | 22 |
| **Applications** |
| Gitea | [gitea.nix](gitea.nix) | Git hosting | 3000 |
| Immich | [immich.nix](immich.nix) | Photo management | 2283 |
| Paperless | [paperless.nix](paperless.nix) | Document management | 28981 |
| Actual | [actual.nix](actual.nix) | Budget management | 5006 |
| Firefly III | [firefly.nix](firefly.nix) | Finance management | 8080 |
| SearXNG | [searx.nix](searx.nix) | Metasearch engine | 8888 |
| **System** |
| Flatpak | [flatpak.nix](flatpak.nix) | Application sandboxing | — |
| Pipewire | [pipewire.nix](pipewire.nix) | Audio/video server | — |
| Printing | [printing.nix](printing.nix) | CUPS printing | 631 |
| Auto-upgrade | [auto-upgrade.nix](auto-upgrade.nix) | Automatic system updates | — |
| Maintenance | [maintenance.nix](maintenance.nix) | System maintenance tasks | — |

### Usage

Enable services in your host configuration:

```nix
sys.services = {
  grafana = {
    enable = true;
    port = 3000;
    openFirewall = true;
  };

  tailscale = {
    enable = true;
    interface = "eth0";
  };

  jellyfin.enable = true;
};
```

### Common Options

Most services provide these standard options:

| Option | Type | Description |
|--------|------|-------------|
| `enable` | bool | Enable the service |
| `port` | port | Port to listen on |
| `openFirewall` | bool | Open firewall for the service port |

### Adding a New Service

Create a new module following this pattern:

```nix
{ lib, config, ... }:
let
  cfg = config.sys.services.<name>;
in
{
  options.sys.services.<name> = {
    enable = lib.mkEnableOption "<service> description";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for <service>";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for <service>";
    };
  };

  config = lib.mkIf cfg.enable {
    services.<upstream-service> = {
      enable = true;
      # Configuration...
    };

    networking.firewall.allowedTCPPorts =
      lib.optionals cfg.openFirewall [ cfg.port ];
  };
}
```

### Related

- [Grafana dashboards library](../../lib/grafana-dashboards.nix)
- [Custom dashboards](../../dashboards/)
