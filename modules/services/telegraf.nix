# Telegraf module for receiving Prometheus remote write and forwarding to InfluxDB
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.telegraf;
  influxdbCfg = config.telometto.services.influxdb;
in
{
  options.telometto.services.telegraf = {
    enable = lib.mkEnableOption "Telegraf as a Prometheus remote write receiver for InfluxDB";

    package = lib.mkPackageOption pkgs "telegraf" { };

    prometheusRemoteWrite = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 11014;
        description = "Port on which Telegraf listens for Prometheus remote write";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address on which Telegraf listens for Prometheus remote write";
      };
    };

    influxdb = {
      url = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString (influxdbCfg.port or 8086)}";
        defaultText = lib.literalExpression ''"http://127.0.0.1:''${toString config.telometto.services.influxdb.port}"'';
        description = "URL of the InfluxDB instance to write to";
      };

      organization = lib.mkOption {
        type = lib.types.str;
        default = influxdbCfg.initialSetup.organization or "homelab";
        defaultText = lib.literalExpression "config.telometto.services.influxdb.initialSetup.organization";
        description = "InfluxDB organization to write to";
      };

      bucket = lib.mkOption {
        type = lib.types.str;
        default = influxdbCfg.prometheusRemoteWrite.bucket or "prometheus";
        defaultText = lib.literalExpression "config.telometto.services.influxdb.prometheusRemoteWrite.bucket";
        description = "InfluxDB bucket to write to";
      };

      tokenFile = lib.mkOption {
        type = lib.types.path;
        default = config.telometto.secrets.influxdbTokenFile or "/run/secrets/influxdb/token";
        defaultText = lib.literalExpression "config.telometto.secrets.influxdbTokenFile";
        description = "Path to file containing the InfluxDB API token";
      };
    };

    # Extra configuration for advanced users
    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra Telegraf configuration to merge";
    };
  };

  config = lib.mkIf cfg.enable {
    services.telegraf = {
      enable = true;
      inherit (cfg) package;

      # Setting environmentFiles causes the upstream module to copy config to /var/run/telegraf/config.toml
      # We use /dev/null as a dummy since we do our own secret substitution
      environmentFiles = [ "/dev/null" ];

      extraConfig = lib.mkMerge [
        {
          # Global agent configuration
          agent = {
            interval = "10s";
            round_interval = true;
            metric_batch_size = 1000;
            metric_buffer_limit = 10000;
            collection_jitter = "0s";
            flush_interval = "10s";
            flush_jitter = "0s";
            precision = "0s";
            hostname = config.networking.hostName;
            omit_hostname = false;
          };

          # Input: Prometheus remote write listener
          inputs.http_listener_v2 = [
            {
              service_address = "${cfg.prometheusRemoteWrite.listenAddress}:${toString cfg.prometheusRemoteWrite.port}";
              paths = [ "/api/v1/write" ];
              data_format = "prometheusremotewrite";
            }
          ];

          # Processor: Convert strings to match InfluxDB requirements
          # Prometheus histograms/summaries can have +Inf which causes serialization issues
          processors.strings = [
            {
              namepass = [ "*" ];
              replace = [
                {
                  tag = "le";
                  old = "+Inf";
                  new = "inf";
                }
                {
                  tag = "quantile";
                  old = "+Inf";
                  new = "inf";
                }
              ];
            }
          ];

          # Output: InfluxDB v2
          outputs.influxdb_v2 = [
            {
              urls = [ cfg.influxdb.url ];
              # Placeholder that gets replaced by replace-secret in ExecStartPre
              token = "@INFLUX_TOKEN@";
              organization = cfg.influxdb.organization;
              bucket = cfg.influxdb.bucket;
            }
          ];
        }
        cfg.extraConfig
      ];
    };

    # Configure systemd service
    systemd.services.telegraf = {
      serviceConfig = {
        # Run replace-secret after the config is copied to /var/run/telegraf/config.toml
        # but before telegraf starts
        ExecStartPre = lib.mkAfter [
          (pkgs.writeShellScript "telegraf-inject-secrets" ''
            ${lib.getExe pkgs.replace-secret} \
              '@INFLUX_TOKEN@' \
              '${cfg.influxdb.tokenFile}' \
              /var/run/telegraf/config.toml
          '')
        ];
      };
      # Ensure telegraf starts after influxdb if it's enabled
      after = lib.mkIf (influxdbCfg.enable or false) [ "influxdb2.service" ];
      wants = lib.mkIf (influxdbCfg.enable or false) [ "influxdb2.service" ];
    };
  };
}
