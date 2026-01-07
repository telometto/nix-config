{ lib, config, ... }:
let
  cfg = config.sys.services.grafanaCloud;
in
{
  options.sys.services.grafanaCloud = {
    enable = lib.mkEnableOption "Grafana Cloud remote write integration";

    username = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Grafana Cloud username (Instance ID) - can be public, or use fileContents to read from a secret";
      example = "123456";
    };

    remoteWriteUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Grafana Cloud Prometheus remote write endpoint URL";
      example = "https://prometheus-prod-XX-XX.grafana.net/api/prom/push";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.path;
      default = config.sys.secrets.grafanaCloudApiKeyFile or "/run/secrets/grafana-cloud-key";
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
    sys.services.prometheus = {
      enable = true;
      listenAddress = lib.mkDefault "127.0.0.1";
      scrapeInterval = lib.mkDefault cfg.scrapeInterval;
    };

    services.prometheus = {
      retentionTime = lib.mkForce cfg.localRetention;

      remoteWrite = lib.mkIf (cfg.username != null && cfg.remoteWriteUrl != "") [
        {
          url = cfg.remoteWriteUrl;

          basic_auth = {
            inherit (cfg) username;
            password_file = cfg.apiKeyFile;
          };

          queue_config = {
            capacity = 10000;
            max_shards = 5;
            min_shards = 1;
            max_samples_per_send = 5000;
            batch_send_deadline = "5s";
            min_backoff = "30ms";
            max_backoff = "5s";
          };

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

    sys.services.prometheusExporters.node.enable = lib.mkDefault true;
  };
}
