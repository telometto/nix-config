# Centralized constants shared across hosts, VMs, and services.
# For secrets use sops-nix; host-local data should remain in host configs.
{
  tailscale = {
    suffix = "mole-delta.ts.net";
    # Shared endpoint consumed by multiple hosts and the Blizzard services.
    hosts.blizzard.ipv4 = "100.86.227.97";
  };

  # Keep host, MicroVM, secondary-service, and network ports in separate
  # namespaces so service ownership is explicit at call sites.
  ports = {
    host = {
      scrutiny = 11001;
      ombi = 11003;
      tautulli = 11004;
      actual = 11005;
      cockpit = 11006;
      victoriametrics = 11008;
      prometheus = 11009;
      grafana = 11010;
      nodeExporter = 11011;
      electricityPriceExporter = 11012;
      zfsExporter = 11013;
      upsExporter = 11014;
      cloudflareMetrics = 11015;
      seaweedfsMaster = 11017;
      seaweedfsVolume = 11018;
      seaweedfsGrpc = 11019;
      seaweedfsFiler = 11020;
      seaweedfsS3 = 11021;
      seaweedfsMetrics = 11022;
      glance = 11064;
    };

    vm = {
      adguard = 11010;
      actual = 11051;
      searx = 11012;
      ombi = 11041;
      tautulli = 11042;
      gitea = 11050;
      sonarr = 11021;
      radarr = 11022;
      prowlarr = 11020;
      bazarr = 11023;
      readarr = 11024;
      lidarr = 11028;
      qbittorrent = 11030;
      overseerr = 11040;
      firefox = 11052;
      wireguard = 56943;
      sabnzbd = 11031;
      flaresolverr = 11013;
      matrixSynapse = 11060;
      paperless = 11061;
      firefly = 11062;
      brave = 11054;
      fireflyImporter = 11063;
      immich = 11070;
      mealie = 11071;
      trigger = 11080;
      pocketId = 11081;
    };

    secondary = {
      immichMachineLearning = rec {
        hostPort = 3003;
        containerPort = hostPort;
      };
      firefoxHttps = 11053;
      braveHttps = 11055;
    };

    network.qbittorrentTorrent = 50820;
  };

  victoriametrics.username = "metrics-writer";
  blackbox = {
    port = 9115;
    jobName = "blackbox";
    probeTimeout = "10s";
    scrapeInterval = "30s";
    scrapeIntervalMs = 30000;
    scrapeTimeout = "15s";
    failureWindow = "10m";
    lookbackSeconds = 300;
    dashboardRefresh = "30s";
  };
}
