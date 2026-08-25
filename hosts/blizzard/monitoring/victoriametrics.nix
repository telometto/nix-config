{ config, consts, ... }:
{
  sys.services.victoriametrics = {
    enable = true;

    port = consts.ports.host.victoriametrics;
    listenAddress = consts.tailscale.hosts.blizzard.ipv4;
    localAddress = consts.tailscale.hosts.blizzard.ipv4;
    httpAuth = {
      username = consts.victoriametrics.username;
      passwordFile = config.sops.secrets."victoriametrics/remote_write_password".path;
    };
    openFirewall = false;
    retentionPeriod = "10y";
    prometheusRemoteWrite = {
      enable = true;
      # Keep login emails available to local Grafana alerting without storing
      # identity-bearing samples for the ten-year VictoriaMetrics retention.
      excludedMetricNames = [
        "cloudflare_access_last_authentication_timestamp_seconds"
      ];
    };

    dedup = {
      enable = true;
      minScrapeInterval = "1ms";
    };

    grafanaDatasource = {
      enable = true;
      name = "VictoriaMetrics (Long-term)";
      uid = null;
      isDefault = true;
    };
  };

  # VictoriaMetrics is reachable only through the encrypted Tailscale
  # interface and still requires HTTP Basic Authentication for every API.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ consts.ports.host.victoriametrics ];

  systemd.services.victoriametrics = {
    after = [
      "tailscaled-autoconnect.service"
      "sops-install-secrets.service"
    ];
    wants = [ "tailscaled-autoconnect.service" ];
    requires = [ "sops-install-secrets.service" ];
  };
}
