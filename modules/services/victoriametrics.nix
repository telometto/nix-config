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
  hasHttpAuth = cfg.httpAuth.username != null && cfg.httpAuth.username != "";
  authorizationEnabled = cfg.authorization.enable or false;
  credentialGroup = "monitoring-credentials";
  authRenderer = ../../lib/victoriametrics-auth.py;
  frontendUnit = "victoriametrics-vmauth";
  frontendRuntime = "/run/${frontendUnit}";
  # The frontend and backend share a port on different interfaces. Local clients
  # must use the frontend too; loopback carries the backend-only credential.
  clientAddress = if authorizationEnabled then cfg.listenAddress else cfg.localAddress;
  externalOctets = builtins.match "([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})" cfg.listenAddress;
  hasExplicitExternalBind =
    externalOctets != null
    && lib.all (part: lib.toIntBase10 part <= 255) externalOctets
    && (
      let
        first = lib.toIntBase10 (builtins.head externalOctets);
      in
      first > 0 && first != 127 && first < 224
    );
  validUsername = name: name != null && builtins.match "[A-Za-z0-9][A-Za-z0-9_.-]*" name != null;
  protectedBackendFlag =
    option:
    let
      flag = lib.removePrefix "-" (lib.removePrefix "-" option);
    in
    lib.any (name: flag == name || lib.hasPrefix "${name}=" flag) [
      "httpListenAddr"
      "httpAuth.username"
      "httpAuth.password"
      "http.pathPrefix"
    ];
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
          Nonempty username for VictoriaMetrics HTTP Basic Authentication. Set this
          together with passwordFile to protect every HTTP endpoint. With
          authorization enabled, this is the ingestion-only frontend identity.
        '';
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          SOPS-managed file containing the VictoriaMetrics HTTP Basic
          Authentication password. The password is loaded through systemd
          credentials and is never placed in the unit command line.
          With authorization enabled, rotation must also restart VictoriaMetrics
          and victoriametrics-vmauth so both revalidate all role passwords.
        '';
      };
    };

    authorization = {
      enable = lib.mkEnableOption ''
        separate ingestion, query and backend authority using vmauth. This requires
        an explicit non-loopback IPv4 listenAddress; the backend uses loopback on
        the same port. Credential rotation requires restarting the consuming units
      '';

      queryUsername = lib.mkOption {
        type = lib.types.str;
        default = "metrics-query";
        description = "Frontend Basic Auth username for Grafana and PromQL reads";
      };

      queryPasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          SOPS-managed query password, loaded through systemd credentials by
          VictoriaMetrics, victoriametrics-vmauth and Grafana. Restart all three
          units when it changes; the backend rechecks role password separation.
        '';
      };

      backendUsername = lib.mkOption {
        type = lib.types.str;
        default = "metrics-backend";
        description = "Backend-only Basic Auth username, unavailable to frontend clients";
      };

      backendPasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          SOPS-managed backend password, loaded through systemd credentials by
          VictoriaMetrics and victoriametrics-vmauth. Restart both units on rotation.
        '';
      };
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address on which the VictoriaMetrics HTTP endpoint listens. With
        authorization enabled, vmauth owns this address and VictoriaMetrics
        moves to the loopback backend.
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
        With authorization enabled, both clients use listenAddress instead so
        they pass through the frontend's role restrictions.
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

      basicAuthUsername =
        if authorizationEnabled then cfg.authorization.backendUsername else cfg.httpAuth.username;
      basicAuthPasswordFile =
        if authorizationEnabled then cfg.authorization.backendPasswordFile else cfg.httpAuth.passwordFile;

      listenAddress = "${
        if authorizationEnabled then "127.0.0.1" else cfg.listenAddress
      }:${toString cfg.port}";

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
              url = "http://${clientAddress}:${toString cfg.port}${cfg.prometheusRemoteWrite.path}";

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
              url = "http://${clientAddress}:${toString cfg.port}";
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
              basicAuthUser =
                if authorizationEnabled then cfg.authorization.queryUsername else cfg.httpAuth.username;
              secureJsonData.basicAuthPassword =
                if authorizationEnabled then
                  "$__file{/run/credentials/grafana.service/victoriametrics-query-password}"
                else
                  "$__file{${cfg.httpAuth.passwordFile}}";
            }
            // lib.optionalAttrs (cfg.grafanaDatasource.uid != null) {
              inherit (cfg.grafanaDatasource) uid;
            }
          )
        ];

    # Open firewall if requested
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    users = {
      users = {
        prometheus.extraGroups = lib.mkIf (hasHttpAuth && (config.services.prometheus.enable or false)) (
          lib.mkAfter [ credentialGroup ]
        );

        grafana.extraGroups = lib.mkIf (
          hasHttpAuth && !authorizationEnabled && (config.sys.services.grafana.enable or false)
        ) (lib.mkAfter [ credentialGroup ]);
      };

      groups.${credentialGroup} = lib.mkIf hasHttpAuth { };
    };

    systemd.services = {
      victoriametrics = lib.mkIf hasHttpAuth {
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
        preStart = lib.mkIf authorizationEnabled ''
          ${pkgs.python3}/bin/python3 ${authRenderer} validate-password \
            "$CREDENTIALS_DIRECTORY/writer-password" \
            "$CREDENTIALS_DIRECTORY/query-password" \
            "$CREDENTIALS_DIRECTORY/basic_auth_password"
        '';
        # Check all three values before opening the loopback backend. Otherwise
        # reused passwords could bypass the frontend despite distinct usernames.
        serviceConfig.LoadCredential = lib.mkIf authorizationEnabled [
          "writer-password:${toString cfg.httpAuth.passwordFile}"
          "query-password:${toString cfg.authorization.queryPasswordFile}"
        ];
      };

      ${frontendUnit} = lib.mkIf authorizationEnabled {
        description = "VictoriaMetrics ingestion and query authorization";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "sops-install-secrets.service"
          "victoriametrics.service"
        ];
        wants = [ "network-online.target" ];
        requires = [
          "sops-install-secrets.service"
          "victoriametrics.service"
        ];
        partOf = [ "victoriametrics.service" ];
        preStart = lib.escapeShellArgs [
          "${pkgs.python3}/bin/python3"
          "${authRenderer}"
          "render"
          "--writer-username"
          (toString cfg.httpAuth.username)
          "--query-username"
          cfg.authorization.queryUsername
          "--backend-username"
          cfg.authorization.backendUsername
          "--backend-url"
          "http://127.0.0.1:${toString cfg.port}"
          "--output"
          "${frontendRuntime}/auth.json"
          "--vmauth-bin"
          "${cfg.package}/bin/vmauth"
        ];
        serviceConfig = {
          ExecStart = lib.escapeShellArgs [
            "${cfg.package}/bin/vmauth"
            "-auth.config=${frontendRuntime}/auth.json"
            "-httpListenAddr=${cfg.listenAddress}:${toString cfg.port}"
            "-httpInternalListenAddr=unix:${frontendRuntime}/internal.sock"
          ];
          LoadCredential = [
            "writer-password:${toString cfg.httpAuth.passwordFile}"
            "query-password:${toString cfg.authorization.queryPasswordFile}"
            "backend-password:${toString cfg.authorization.backendPasswordFile}"
          ];
          DynamicUser = true;
          RuntimeDirectory = frontendUnit;
          RuntimeDirectoryMode = "0700";
          UMask = "0077";
          Restart = "on-failure";
          RestartSec = 2;
          CapabilityBoundingSet = "";
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
        };
      };

      prometheus = lib.mkIf (hasHttpAuth && (config.services.prometheus.enable or false)) {
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
      };

      grafana = lib.mkIf (hasHttpAuth && (config.sys.services.grafana.enable or false)) {
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
        serviceConfig.LoadCredential = lib.mkIf authorizationEnabled [
          "victoriametrics-query-password:${toString cfg.authorization.queryPasswordFile}"
        ];
      };
    };

    assertions = [
      {
        assertion =
          !authorizationEnabled
          || (
            hasHttpAuth
            && cfg.authorization.queryPasswordFile != null
            && cfg.authorization.backendPasswordFile != null
          );
        message = "sys.services.victoriametrics.authorization requires ingestion, query and backend password files";
      }
      {
        assertion = !authorizationEnabled || hasExplicitExternalBind;
        message = "sys.services.victoriametrics.authorization requires an explicit non-loopback IPv4 listenAddress";
      }
      {
        assertion =
          !authorizationEnabled
          || (
            lib.all validUsername [
              cfg.httpAuth.username
              cfg.authorization.queryUsername
              cfg.authorization.backendUsername
            ]
            &&
              builtins.length (
                lib.unique [
                  cfg.httpAuth.username
                  cfg.authorization.queryUsername
                  cfg.authorization.backendUsername
                ]
              ) == 3
          );
        message = "sys.services.victoriametrics.authorization requires distinct nonempty ingestion, query and backend usernames using letters, digits, dots, underscores or hyphens";
      }
      {
        assertion = !authorizationEnabled || cfg.prometheusRemoteWrite.path == "/api/v1/write";
        message = "sys.services.victoriametrics.authorization restricts ingestion to /api/v1/write";
      }
      {
        assertion = !authorizationEnabled || !(lib.any protectedBackendFlag cfg.extraOptions);
        message = "sys.services.victoriametrics.authorization forbids overriding backend HTTP listener, authentication or path prefix flags";
      }
      {
        assertion = cfg.httpAuth.username == null || cfg.httpAuth.username != "";
        message = "sys.services.victoriametrics.httpAuth.username must be nonempty when set";
      }
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
