_: {
  sys.services.victoriametrics = {
    enable = true;

    listenAddress = "127.0.0.1";
    openFirewall = false;
    retentionPeriod = "10y";
    prometheusRemoteWrite.enable = true;

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
