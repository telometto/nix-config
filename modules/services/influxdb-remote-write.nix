# Module for configuring Prometheus to remote write to a central InfluxDB instance
# Use this on hosts that don't run InfluxDB but want to send metrics to one
# Note: The remote host must be running Telegraf to receive Prometheus remote write
{
  lib,
  config,
  ...
}:
let
  cfg = config.telometto.services.influxdbRemoteWrite;
in
{
  options.telometto.services.influxdbRemoteWrite = {
    enable = lib.mkEnableOption "Prometheus remote write to a central InfluxDB instance via Telegraf";

    telegrafHost = lib.mkOption {
      type = lib.types.str;
      default = "blizzard";
      description = ''
        Hostname or IP address of the Telegraf server (which forwards to InfluxDB).
        Can be a Tailscale hostname (e.g., "blizzard") or IP address.
      '';
      example = "192.168.1.100";
    };

    telegrafPort = lib.mkOption {
      type = lib.types.port;
      default = 11014;
      description = "Port on which the remote Telegraf listens for Prometheus remote write";
    };

    # Legacy options for backwards compatibility
    influxdbHost = lib.mkOption {
      type = lib.types.str;
      default = cfg.telegrafHost;
      description = "Deprecated: Use telegrafHost instead";
      visible = false;
    };

    influxdbPort = lib.mkOption {
      type = lib.types.port;
      default = 8086;
      description = "Deprecated: Use telegrafPort instead. This is now ignored.";
      visible = false;
    };

    organization = lib.mkOption {
      type = lib.types.str;
      default = "homelab";
      description = "InfluxDB organization (for documentation, Telegraf handles this)";
    };

    bucket = lib.mkOption {
      type = lib.types.str;
      default = "prometheus";
      description = "InfluxDB bucket (for documentation, Telegraf handles this)";
    };

    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Deprecated: Token is no longer needed for remote write.
        Telegraf on the receiving end handles authentication to InfluxDB.
      '';
    };

    useHttps = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use HTTPS for the connection to Telegraf";
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
          config.services.prometheus.enable or config.telometto.services.prometheus.enable or false;
        message = "influxdbRemoteWrite requires Prometheus to be enabled";
      }
      {
        assertion = !config.telometto.services.influxdb.enable or false;
        message = ''
          influxdbRemoteWrite should not be used on hosts running InfluxDB locally.
          Use telometto.services.influxdb.prometheusRemoteWrite instead.
        '';
      }
    ];

    services.prometheus.remoteWrite = [
      {
        url =
          let
            protocol = if cfg.useHttps then "https" else "http";
          in
          # Write to Telegraf's Prometheus remote write endpoint
          "${protocol}://${cfg.telegrafHost}:${toString cfg.telegrafPort}/api/v1/write";

        queue_config = {
          capacity = cfg.queueConfig.capacity;
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
