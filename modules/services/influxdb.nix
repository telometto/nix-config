{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.influxdb;
in
{
  options.telometto.services.influxdb = {
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
        default = config.telometto.secrets.influxdbPasswordFile or "/run/secrets/influxdb-password";
        defaultText = lib.literalExpression "config.telometto.secrets.influxdbPasswordFile";
        description = "Path to file containing the admin password. Do not use a file from the nix store!";
        example = "/run/secrets/influxdb-password";
      };

      tokenFile = lib.mkOption {
        type = lib.types.path;
        default = config.telometto.secrets.influxdbTokenFile or "/run/secrets/influxdb-token";
        defaultText = lib.literalExpression "config.telometto.secrets.influxdbTokenFile";
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

    # Prometheus remote write integration
    prometheusRemoteWrite = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Configure Prometheus to remote write to this InfluxDB instance";
      };

      bucket = lib.mkOption {
        type = lib.types.str;
        default = "prometheus";
        description = "InfluxDB bucket to write Prometheus metrics to";
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

          # Create a token for Prometheus remote write
          auths.prometheus-remote-write = lib.mkIf cfg.prometheusRemoteWrite.enable {
            description = "Token for Prometheus remote write";
            writeBuckets = [ cfg.prometheusRemoteWrite.bucket ];
            tokenFile = cfg.initialSetup.tokenFile; # Reuse admin token for simplicity
          };
        };
      };
    };

    # Configure Prometheus remote write to InfluxDB
    services.prometheus.remoteWrite =
      lib.mkIf (cfg.prometheusRemoteWrite.enable && config.services.prometheus.enable or false)
        [
          {
            url = "http://127.0.0.1:${toString cfg.port}/api/v1/prom/write?org=${cfg.initialSetup.organization}&bucket=${cfg.prometheusRemoteWrite.bucket}";
            bearer_token_file = cfg.initialSetup.tokenFile;

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
                target_label = "instance";
                replacement = config.networking.hostName;
              }
            ];
          }
        ];

    # Add InfluxDB as Grafana datasource
    telometto.services.grafana.provision.datasources =
      lib.mkIf (cfg.grafanaDatasource.enable && config.telometto.services.grafana.enable or false)
        [
          {
            name = cfg.grafanaDatasource.name;
            type = "influxdb";
            access = "proxy";
            url = "http://127.0.0.1:${toString cfg.port}";
            jsonData = {
              version = "Flux";
              organization = cfg.initialSetup.organization;
              defaultBucket = cfg.prometheusRemoteWrite.bucket;
            };
            secureJsonData = {
              token = "$__file{${cfg.initialSetup.tokenFile}}";
            };
            isDefault = cfg.grafanaDatasource.isDefault;
            editable = false;
          }
        ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
