{ lib, config, ... }:
let
  cfg = config.telometto.services.grafanaCloud;
in
{
  options.telometto.services.grafanaCloud = {
    enable = lib.mkEnableOption "Grafana Cloud remote write integration";

    remoteWriteUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Grafana Cloud Prometheus remote write endpoint URL";
      example = "https://prometheus-prod-XX-XX.grafana.net/api/prom/push";
    };

    usernameFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = config.telometto.secrets.grafanaCloudUsername or null;
      description = "Path to file containing Grafana Cloud username (Instance ID)";
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

          # Authentication using basic auth
          basic_auth = {
            username_file = cfg.usernameFile;
            password_file = cfg.apiKeyFile;
          };

          # Queue configuration for reliability
          queue_config = {
            capacity = 10000; # Buffer capacity
            max_shards = 5; # Parallel upload streams
            min_shards = 1;
            max_samples_per_send = 5000; # Batch size
            batch_send_deadline = "5s"; # Send batches every 5s
            min_backoff = "30ms"; # Retry backoff
            max_backoff = "5s";
          };

          # Add hostname to all metrics
          write_relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "instance";
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
