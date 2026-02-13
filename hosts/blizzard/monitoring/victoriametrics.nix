_: {
  sys.services.victoriametrics = {
    enable = true;

    listenAddress = "0.0.0.0";
    openFirewall = true;
    retentionPeriod = "1y";
    prometheusRemoteWrite.enable = true;

    dedup = {
      enable = true;
      minScrapeInterval = "1ms";
    };

    grafanaDatasource = {
      enable = true;
      name = "VictoriaMetrics (Long-term)";
    };
  };
}
