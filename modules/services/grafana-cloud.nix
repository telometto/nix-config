{ lib, config, ... }:
let
  cfg = config.telometto.services.grafanaCloud;
in
{
  options.telometto.services.grafanaCloud = {
    enable = lib.mkEnableOption "Grafana Cloud remote write integration";

    remoteWriteUrl = lib.mkOption {
      type = lib.types.str;
      default = config.telometto.secrets.grafanaCloudRemoteWriteUrl or "";
      description = "Grafana Cloud Prometheus remote write endpoint URL (from SOPS by default)";
      example = "https://prometheus-prod-XX-XX.grafana.net/api/prom/push";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = config.telometto.secrets.grafanaCloudUsername or "";
      description = "Grafana Cloud username (Instance ID) (from SOPS by default)";
      example = "123456";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.path;
      default = config.telometto.secrets.grafanaCloudApiKeyFile or "/run/secrets/grafana-cloud-key";
      description = ''
        Path to file containing the Grafana Cloud API key (from SOPS by default).
        Falls back to /run/secrets/grafana-cloud-key if not using SOPS.
      '';
    };

    localRetention = lib.mkOption {
      type = lib.types.str;
      default = "2h";
      description = "Local Prometheus retention time (buffer for when cloud is unreachable)";
    };

    scrapeInterval = lib.mkOption {
      type = lib.types.str;
      default = "15s";
      description = "How often to scrape metrics";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable local Prometheus for scraping and buffering
    telometto.services.prometheus = {
      enable = true;
      listenAddress = lib.mkDefault "127.0.0.1"; # Local only by default
      scrapeInterval = lib.mkDefault cfg.scrapeInterval;
    };

    # Configure Prometheus remote write to Grafana Cloud
    services.prometheus = {
      retentionTime = lib.mkForce cfg.localRetention; # Override prometheus module default

      remoteWrite = [
        {
          url = cfg.remoteWriteUrl;

          # Authentication
          basicAuth = {
            username = cfg.username;
            passwordFile = cfg.apiKeyFile;
          };

          # Queue configuration for reliability
          queueConfig = {
            capacity = 10000; # Buffer capacity
            maxShards = 5; # Parallel upload streams
            minShards = 1;
            maxSamplesPerSend = 5000; # Batch size
            batchSendDeadline = "5s"; # Send batches every 5s
            minBackoff = "30ms"; # Retry backoff
            maxBackoff = "5s";
          };

          # Add hostname to all metrics
          writeRelabelConfigs = [
            {
              sourceLabels = [ "__address__" ];
              targetLabel = "instance";
              replacement = config.networking.hostName;
            }
          ];
        }
      ];
    };

    # Enable node exporter by default
    telometto.services.prometheusExporters.node.enable = lib.mkDefault true;
  };
}
