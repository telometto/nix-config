# Centralized constants shared across hosts, VMs, and services.
# For secrets use sops-nix; for per-host data use host configs.
{
  tailscale.suffix = "mole-delta.ts.net";

  blackbox = {
    port = 9115;
    jobName = "blackbox";
    probeTimeout = "10s";
    scrapeInterval = "30s";
    scrapeIntervalMs = 30000;
    scrapeTimeout = "15s";
    failureWindow = "5m";
    lookbackSeconds = 300;
    dashboardRefresh = "30s";
  };
}
