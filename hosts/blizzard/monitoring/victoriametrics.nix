_: {
  sys.services.victoriametrics = {
    enable = true;

    listenAddress = "127.0.0.1";
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
}
