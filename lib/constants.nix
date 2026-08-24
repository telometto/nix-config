# Centralized constants shared across hosts, VMs, and services.
# For secrets use sops-nix; host-local data should remain in host configs.
let
  blackboxPortValue = 9115;
in
{
  tailscale = {
    suffix = "mole-delta.ts.net";
    # Shared endpoint consumed by multiple hosts and the Blizzard services.
    hosts.blizzard.ipv4 = "100.86.227.97";
  };

  # Blizzard host service ports.
  scrutinyPort = 11001;
  ombiHostPort = 11003;
  tautulliHostPort = 11004;
  actualHostPort = 11005;
  cockpitPort = 11006;
  victoriametricsPort = 11008;
  prometheusPort = 11009;
  grafanaPort = 11010;
  nodeExporterPort = 11011;
  electricityPriceExporterPort = 11012;
  zfsExporterPort = 11013;
  upsExporterPort = 11014;
  cloudflareMetricsPort = 11015;
  seaweedfsMasterPort = 11017;
  seaweedfsVolumePort = 11018;
  seaweedfsGrpcPort = 11019;
  seaweedfsFilerPort = 11020;
  seaweedfsS3Port = 11021;
  seaweedfsMetricsPort = 11022;
  glancePort = 11064;

  # MicroVM primary service ports.
  adguardPort = 11010;
  actualPort = 11051;
  searxPort = 11012;
  ombiPort = 11041;
  tautulliPort = 11042;
  giteaPort = 11050;
  sonarrPort = 11021;
  radarrPort = 11022;
  prowlarrPort = 11020;
  bazarrPort = 11023;
  readarrPort = 11024;
  lidarrPort = 11028;
  qbittorrentPort = 11030;
  qbittorrentTorrentPort = 50820;
  overseerrPort = 11040;
  firefoxPort = 11052;
  wireguardPort = 56943;
  sabnzbdPort = 11031;
  flaresolverrPort = 11013;
  matrixSynapsePort = 11060;
  paperlessPort = 11061;
  fireflyPort = 11062;
  bravePort = 11054;
  fireflyImporterPort = 11063;
  immichPort = 11070;
  mealiePort = 11071;
  triggerPort = 11080;
  pocketIdPort = 11081;

  # Secondary service endpoints.
  immichMachineLearningPort = 3003;
  firefoxHttpsPort = 11053;
  braveHttpsPort = 11055;

  blackboxPort = blackboxPortValue;
  blackbox = {
    port = blackboxPortValue;
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
