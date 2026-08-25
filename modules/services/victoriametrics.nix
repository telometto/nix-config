# VictoriaMetrics module for long-term metrics storage
# Replaces InfluxDB + Telegraf with a simpler, more performant solution
# VictoriaMetrics natively supports Prometheus remote write
{
  lib,
  config,
  pkgs,
  consts,
  ...
}:
let
  cfg = config.sys.services.victoriametrics;
  hasHttpAuth = cfg.httpAuth.username != null;
  credentialGroup = "monitoring-credentials";
in
{
  options.sys.services.victoriametrics = {
    enable = lib.mkEnableOption "VictoriaMetrics time-series database for long-term metrics storage";

    package = lib.mkPackageOption pkgs "victoriametrics" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = consts.ports.host.victoriametrics;
      description = "Port on which VictoriaMetrics listens for HTTP requests";
    };

    httpAuth = {
      username = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Username for VictoriaMetrics HTTP Basic Authentication. Set this
          together with passwordFile to protect every HTTP endpoint.
        '';
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          SOPS-managed file containing the VictoriaMetrics HTTP Basic
          Authentication password. The password is loaded through systemd
          credentials and is never placed in the unit command line.
        '';
      };
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address on which VictoriaMetrics listens.
        Remote clients require a reachable non-loopback address. Bind to the
        narrowest interface that serves the intended clients.
      '';
      example = "100.86.227.97";
    };

    localAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address used by local Prometheus and Grafana clients to reach VictoriaMetrics.
        Set this when listenAddress does not include the loopback interface.
      '';
      example = "127.0.0.1";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for VictoriaMetrics port";
    };

    retentionPeriod = lib.mkOption {
      type = lib.types.str;
      default = "10y";
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

      excludedMetricNames = lib.mkOption {
        type = lib.types.listOf (lib.types.strMatching "[A-Za-z_:][A-Za-z0-9_:]*");
        default = [ ];
        description = ''
          Exact Prometheus metric names to keep in local Prometheus without
          copying them into long-term VictoriaMetrics storage.
        '';
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

      uid = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "victoriametrics";
        description = "Optional stable Grafana datasource UID for VictoriaMetrics";
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

      basicAuthUsername = cfg.httpAuth.username;
      basicAuthPasswordFile = cfg.httpAuth.passwordFile;

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
          (
            {
              url = "http://${cfg.localAddress}:${toString cfg.port}${cfg.prometheusRemoteWrite.path}";

              queue_config = {
                capacity = 10000;
                max_shards = 3;
                min_shards = 1;
                max_samples_per_send = 1000;
                batch_send_deadline = "5s";
                min_backoff = "30ms";
                max_backoff = "5s";
              };

              write_relabel_configs =
                lib.optionals (cfg.prometheusRemoteWrite.excludedMetricNames != [ ]) [
                  {
                    source_labels = [ "__name__" ];
                    regex = lib.concatStringsSep "|" cfg.prometheusRemoteWrite.excludedMetricNames;
                    action = "drop";
                  }
                ]
                ++ [
                  {
                    source_labels = [ "__address__" ];
                    target_label = "source_host";
                    replacement = config.networking.hostName;
                  }
                ];
            }
            // lib.optionalAttrs hasHttpAuth {
              basic_auth = {
                username = cfg.httpAuth.username;
                password_file = cfg.httpAuth.passwordFile;
              };
            }
          )
        ];

    # Add VictoriaMetrics as Grafana datasource
    # VictoriaMetrics is 100% compatible with Prometheus datasource type
    sys.services.grafana.provision.deleteDatasources =
      lib.mkIf (cfg.grafanaDatasource.enable && config.sys.services.grafana.enable or false)
        [
          {
            inherit (cfg.grafanaDatasource) name;
            orgId = 1;
          }
        ];

    sys.services.grafana.provision.datasources =
      lib.mkIf (cfg.grafanaDatasource.enable && config.sys.services.grafana.enable or false)
        [
          (
            {
              inherit (cfg.grafanaDatasource) name isDefault;
              type = "prometheus"; # VictoriaMetrics is PromQL-compatible
              access = "proxy";
              url = "http://${cfg.localAddress}:${toString cfg.port}";
              editable = false;
              jsonData = {
                # VictoriaMetrics supports Prometheus-compatible API
                httpMethod = "POST";
                # Enable range queries for better performance
                manageAlerts = false;
              };
            }
            // lib.optionalAttrs hasHttpAuth {
              basicAuth = true;
              basicAuthUser = cfg.httpAuth.username;
              secureJsonData.basicAuthPassword = "$__file{${cfg.httpAuth.passwordFile}}";
            }
            // lib.optionalAttrs (cfg.grafanaDatasource.uid != null) {
              inherit (cfg.grafanaDatasource) uid;
            }
          )
        ];

    # Open firewall if requested
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    users.groups.${credentialGroup} = lib.mkIf hasHttpAuth { };
    users.users.prometheus.extraGroups = lib.mkIf (
      hasHttpAuth && (config.services.prometheus.enable or false)
    ) (lib.mkAfter [ credentialGroup ]);
    users.users.grafana.extraGroups = lib.mkIf (
      hasHttpAuth && (config.sys.services.grafana.enable or false)
    ) (lib.mkAfter [ credentialGroup ]);

    systemd.services.victoriametrics = lib.mkIf hasHttpAuth {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
    };

    systemd.services.prometheus =
      lib.mkIf (hasHttpAuth && (config.services.prometheus.enable or false))
        {
          after = [ "sops-install-secrets.service" ];
          requires = [ "sops-install-secrets.service" ];
        };

    systemd.services.grafana = lib.mkIf (hasHttpAuth && (config.sys.services.grafana.enable or false)) {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
    };

    assertions = [
      {
        assertion = (cfg.httpAuth.username == null) == (cfg.httpAuth.passwordFile == null);
        message = "sys.services.victoriametrics.httpAuth.username and passwordFile must both be set or both be null";
      }
      {
        assertion =
          lib.elem cfg.listenAddress [
            "127.0.0.1"
            "::1"
            "localhost"
          ]
          || hasHttpAuth;
        message = "sys.services.victoriametrics requires HTTP Basic Authentication when listenAddress is not loopback";
      }
    ];
  };
}
