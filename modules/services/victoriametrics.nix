# VictoriaMetrics module for long-term metrics storage
# Replaces InfluxDB + Telegraf with a simpler, more performant solution
# VictoriaMetrics natively supports Prometheus remote write
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.victoriametrics;
in
{
  options.telometto.services.victoriametrics = {
    enable = lib.mkEnableOption "VictoriaMetrics time-series database for long-term metrics storage";

    package = lib.mkPackageOption pkgs "victoriametrics" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11008;
      description = "Port on which VictoriaMetrics listens for HTTP requests";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address on which VictoriaMetrics listens.
        Set to "0.0.0.0" to listen on all interfaces (required for remote write from other hosts).
      '';
      example = "0.0.0.0";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for VictoriaMetrics port";
    };

    retentionPeriod = lib.mkOption {
      type = lib.types.str;
      default = "10y"; # 12 months by default
      description = ''
        How long to retain samples in storage.
        The minimum retentionPeriod is 24h or 1d.
        Supported suffixes: s (second), h (hour), d (day), w (week), y (year).
        If no suffix, the duration is counted in months.
      '';
      example = "1y";
    };

    # Prometheus remote write configuration
    prometheusRemoteWrite = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Configure local Prometheus to remote write to VictoriaMetrics";
      };

      # VictoriaMetrics accepts Prometheus remote write at /api/v1/write by default
      path = lib.mkOption {
        type = lib.types.str;
        default = "/api/v1/write";
        description = "URL path for Prometheus remote write endpoint";
      };
    };

    # Grafana datasource integration
    grafanaDatasource = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically provision VictoriaMetrics as a Grafana datasource";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "VictoriaMetrics";
        description = "Name of the Grafana datasource";
      };

      isDefault = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Set VictoriaMetrics as the default Grafana datasource";
      };
    };

    # Deduplication for metrics from multiple sources
    dedup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable deduplication of incoming samples.
          Useful when receiving metrics from multiple Prometheus instances.
        '';
      };

      minScrapeInterval = lib.mkOption {
        type = lib.types.str;
        default = "1ms";
        description = ''
          Minimum interval for deduplication.
          Samples with timestamps closer than this are deduplicated.
        '';
        example = "15s";
      };
    };

    # Memory and performance settings
    memory = {
      allowedPercent = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = ''
          Allowed percent of system memory VictoriaMetrics may use for caches.
          If not set, VictoriaMetrics will use reasonable defaults.
        '';
        example = 60;
      };
    };

    # Extra CLI options for advanced configuration
    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra command-line options to pass to VictoriaMetrics.
        See https://docs.victoriametrics.com/single-server-victoriametrics/#list-of-command-line-flags
      '';
      example = lib.literalExpression ''
        [
          "-loggerLevel=WARN"
          "-search.latencyOffset=30s"
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.victoriametrics = {
      enable = true;
      inherit (cfg) package retentionPeriod;

      listenAddress = "${cfg.listenAddress}:${toString cfg.port}";

      extraOptions =
        cfg.extraOptions
        ++ lib.optionals cfg.dedup.enable [
          "-dedup.minScrapeInterval=${cfg.dedup.minScrapeInterval}"
        ]
        ++ lib.optionals (cfg.memory.allowedPercent != null) [
          "-memory.allowedPercent=${toString cfg.memory.allowedPercent}"
        ];
    };

    # Configure Prometheus remote write to VictoriaMetrics
    services.prometheus.remoteWrite =
      lib.mkIf (cfg.prometheusRemoteWrite.enable && config.services.prometheus.enable or false)
        [
          {
            url = "http://127.0.0.1:${toString cfg.port}${cfg.prometheusRemoteWrite.path}";

            queue_config = {
              capacity = 10000;
              max_shards = 3;
              min_shards = 1;
              max_samples_per_send = 1000;
              batch_send_deadline = "5s";
              min_backoff = "30ms";
              max_backoff = "5s";
            };

            # Add hostname label to all metrics
            write_relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "source_host";
                replacement = config.networking.hostName;
              }
            ];
          }
        ];

    # Add VictoriaMetrics as Grafana datasource
    # VictoriaMetrics is 100% compatible with Prometheus datasource type
    telometto.services.grafana.provision.datasources =
      lib.mkIf (cfg.grafanaDatasource.enable && config.telometto.services.grafana.enable or false)
        [
          {
            inherit (cfg.grafanaDatasource) name isDefault;
            type = "prometheus"; # VictoriaMetrics is PromQL-compatible
            access = "proxy";
            url = "http://127.0.0.1:${toString cfg.port}";
            editable = false;
            jsonData = {
              # VictoriaMetrics supports Prometheus-compatible API
              httpMethod = "POST";
              # Enable range queries for better performance
              manageAlerts = false;
            };
          }
        ];

    # Open firewall if requested
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
