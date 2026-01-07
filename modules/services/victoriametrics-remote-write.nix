# Module for configuring Prometheus to remote write to a central VictoriaMetrics instance
# Use this on hosts that don't run VictoriaMetrics but want to send metrics to one
{
  lib,
  config,
  ...
}:
let
  cfg = config.sys.services.victoriametricsRemoteWrite;
in
{
  options.sys.services.victoriametricsRemoteWrite = {
    enable = lib.mkEnableOption "Prometheus remote write to a central VictoriaMetrics instance";

    vmHost = lib.mkOption {
      type = lib.types.str;
      default = "blizzard";
      description = ''
        Hostname or IP address of the VictoriaMetrics server.
        Can be a Tailscale hostname (e.g., "blizzard") or IP address.
      '';
      example = "192.168.1.100";
    };

    vmPort = lib.mkOption {
      type = lib.types.port;
      default = 11008;
      description = "Port on which the remote VictoriaMetrics listens";
    };

    path = lib.mkOption {
      type = lib.types.str;
      default = "/api/v1/write";
      description = "URL path for Prometheus remote write endpoint";
    };

    useHttps = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use HTTPS for the connection to VictoriaMetrics";
    };

    queueConfig = {
      capacity = lib.mkOption {
        type = lib.types.int;
        default = 10000;
        description = "Number of samples to buffer per shard before blocking";
      };

      maxShards = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Maximum number of shards (parallel writers)";
      };

      minShards = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Minimum number of shards";
      };

      maxSamplesPerSend = lib.mkOption {
        type = lib.types.int;
        default = 1000;
        description = "Maximum number of samples per send";
      };

      batchSendDeadline = lib.mkOption {
        type = lib.types.str;
        default = "5s";
        description = "Maximum time a sample will wait in buffer";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          config.services.prometheus.enable or config.sys.services.prometheus.enable or false;
        message = "victoriametricsRemoteWrite requires Prometheus to be enabled";
      }
      {
        assertion = !config.sys.services.victoriametrics.enable or false;
        message = ''
          victoriametricsRemoteWrite should not be used on hosts running VictoriaMetrics locally.
          Use sys.services.victoriametrics.prometheusRemoteWrite instead.
        '';
      }
    ];

    services.prometheus.remoteWrite = [
      {
        url =
          let
            protocol = if cfg.useHttps then "https" else "http";
          in
          "${protocol}://${cfg.vmHost}:${toString cfg.vmPort}${cfg.path}";

        queue_config = {
          inherit (cfg.queueConfig) capacity;

          max_shards = cfg.queueConfig.maxShards;
          min_shards = cfg.queueConfig.minShards;
          max_samples_per_send = cfg.queueConfig.maxSamplesPerSend;
          batch_send_deadline = cfg.queueConfig.batchSendDeadline;
          min_backoff = "30ms";
          max_backoff = "5s";
        };

        # Add hostname label to all metrics for identification
        write_relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "source_host";
            replacement = config.networking.hostName;
          }
        ];
      }
    ];
  };
}
