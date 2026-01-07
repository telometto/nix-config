{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.influxdb;
in
{
  options.sys.services.influxdb = {
    enable = lib.mkEnableOption "InfluxDB 2.x time-series database for long-term metrics storage";

    package = lib.mkPackageOption pkgs "influxdb2" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8086;
      description = "Port on which InfluxDB listens";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address on which InfluxDB listens.
        Set to "0.0.0.0" to listen on all interfaces (required for remote write from other hosts).
      '';
      example = "0.0.0.0";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for InfluxDB port";
    };

    # Initial setup configuration
    initialSetup = {
      organization = lib.mkOption {
        type = lib.types.str;
        default = "homelab";
        description = "Primary organization name for initial setup";
      };

      bucket = lib.mkOption {
        type = lib.types.str;
        default = "prometheus";
        description = "Primary bucket name for Prometheus metrics";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Admin username for initial setup";
      };

      retention = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Retention period in seconds for the primary bucket (0 = infinite)";
        example = 31536000; # 1 year
      };

      passwordFile = lib.mkOption {
        type = lib.types.path;
        default = config.sys.secrets.influxdbPasswordFile or "/run/secrets/influxdb-password";
        defaultText = lib.literalExpression "config.sys.secrets.influxdbPasswordFile";
        description = "Path to file containing the admin password. Do not use a file from the nix store!";
        example = "/run/secrets/influxdb-password";
      };

      tokenFile = lib.mkOption {
        type = lib.types.path;
        default = config.sys.secrets.influxdbTokenFile or "/run/secrets/influxdb-token";
        defaultText = lib.literalExpression "config.sys.secrets.influxdbTokenFile";
        description = "Path to file containing the admin API token. Do not use a file from the nix store!";
        example = "/run/secrets/influxdb-token";
      };
    };

    # Additional buckets for different retention policies
    extraBuckets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            description = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional description for the bucket";
            };

            retention = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Retention period in seconds (0 = infinite)";
            };
          };
        }
      );
      default = { };
      description = "Additional buckets to create";
      example = lib.literalExpression ''
        {
          metrics-30d = {
            description = "Short-term high-resolution metrics";
            retention = 2592000;  # 30 days
          };
          metrics-1y = {
            description = "Long-term downsampled metrics";
            retention = 31536000;  # 1 year
          };
        }
      '';
    };

    # Prometheus remote write integration (via Telegraf)
    prometheusRemoteWrite = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Configure Prometheus to remote write to InfluxDB via Telegraf";
      };

      bucket = lib.mkOption {
        type = lib.types.str;
        default = "prometheus";
        description = "InfluxDB bucket to write Prometheus metrics to";
      };
    };

    # Telegraf integration for Prometheus remote write
    telegraf = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable Telegraf as a Prometheus remote write receiver.
          InfluxDB 2.x OSS doesn't have a native Prometheus remote write endpoint,
          so Telegraf acts as a translator.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 11014;
        description = "Port on which Telegraf listens for Prometheus remote write";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = ''
          Address on which Telegraf listens for Prometheus remote write.
          Set to "0.0.0.0" to accept connections from remote hosts.
        '';
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open the firewall for Telegraf's Prometheus remote write port";
      };
    };

    # Grafana datasource integration
    grafanaDatasource = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically provision InfluxDB as a Grafana datasource";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "InfluxDB";
        description = "Name of the Grafana datasource";
      };

      isDefault = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Set InfluxDB as the default Grafana datasource";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.influxdb2 = {
      enable = true;
      inherit (cfg) package;

      settings = {
        http-bind-address = "${cfg.listenAddress}:${toString cfg.port}";
      };

      provision = {
        enable = true;

        initialSetup = {
          inherit (cfg.initialSetup)
            organization
            bucket
            username
            retention
            passwordFile
            tokenFile
            ;
        };

        organizations.${cfg.initialSetup.organization} = {
          buckets = lib.mapAttrs (name: bucketCfg: {
            inherit (bucketCfg) description retention;
          }) cfg.extraBuckets;

          # Note: We intentionally don't create a separate prometheus-remote-write token.
          # The admin token (from initialSetup.tokenFile) is used directly for Prometheus
          # remote write. This is simpler and avoids issues with token conflicts.
          # If you need a restricted token, create a separate sops secret for it.
        };
      };
    };

    # Enable Telegraf as Prometheus remote write receiver
    sys.services.telegraf = lib.mkIf (cfg.prometheusRemoteWrite.enable && cfg.telegraf.enable) {
      enable = true;
      prometheusRemoteWrite = {
        inherit (cfg.telegraf) port listenAddress;
      };
      influxdb = {
        url = "http://127.0.0.1:${toString cfg.port}";
        inherit (cfg.initialSetup)
          organization
          bucket
          tokenFile
          ;
      };
    };

    # Configure Prometheus remote write to Telegraf (which forwards to InfluxDB)
    services.prometheus.remoteWrite =
      lib.mkIf
        (
          cfg.prometheusRemoteWrite.enable
          && cfg.telegraf.enable
          && config.services.prometheus.enable or false
        )
        [
          {
            # Write to Telegraf, not directly to InfluxDB
            url = "http://127.0.0.1:${toString cfg.telegraf.port}/api/v1/write";

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

    # Add InfluxDB as Grafana datasource
    sys.services.grafana.provision.datasources =
      lib.mkIf (cfg.grafanaDatasource.enable && config.sys.services.grafana.enable or false)
        [
          {
            inherit (cfg.grafanaDatasource) name;
            type = "influxdb";
            access = "proxy";
            url = "http://127.0.0.1:${toString cfg.port}";
            jsonData = {
              version = "Flux";
              inherit (cfg.initialSetup) organization;
              defaultBucket = cfg.prometheusRemoteWrite.bucket;
            };
            secureJsonData = {
              token = "$__file{${cfg.initialSetup.tokenFile}}";
            };
            inherit (cfg.grafanaDatasource) isDefault;
            editable = false;
          }
        ];

    # Open firewall for InfluxDB and/or Telegraf
    networking.firewall.allowedTCPPorts =
      (lib.optional cfg.openFirewall cfg.port)
      ++ (lib.optional cfg.telegraf.openFirewall cfg.telegraf.port);
  };
}
