{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.matrix-synapse;
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.matrix-synapse = {
    enable = lib.mkEnableOption "Matrix Synapse homeserver";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8008;
      description = "HTTP listener port for Synapse (client + federation).";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      description = "The public-facing domain for Matrix user IDs (@user:domain).";
      example = "example.com";
    };

    publicBaseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Public-facing base URL. Defaults to https://<reverseProxy.domain> if set.";
      example = "https://matrix.example.com";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/matrix-synapse";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    database.createLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create a local PostgreSQL database for Synapse.";
    };

    urlPreview.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable URL preview generation for linked content.";
    };

    extraConfigFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra YAML config files merged at startup (e.g. for registration_shared_secret).";
    };

    reverseProxy = traefikLib.mkReverseProxyOptions {
      name = "matrix-synapse";
      defaults.enable = false;
    };

    authDelegation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Delegate authentication to Matrix Authentication Service (MAS).
          When enabled, Synapse's built-in user registration is disabled and
          MAS handles authentication via the matrix_authentication_service
          config block.  The shared secret must be injected at runtime via
          extraConfigFiles.
        '';
      };

      issuer = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "MAS OIDC issuer URL (e.g. https://matrix.example.com/).";
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "0000000000000000000SYNAPSE";
        description = "OIDC client ID registered in MAS for Synapse.";
      };

      clientAuthMethod = lib.mkOption {
        type = lib.types.str;
        default = "client_secret_basic";
        description = "OIDC client authentication method.";
      };

      accountManagementUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "MAS account management URL shown to users.";
        example = "https://matrix.example.com/account/";
      };

      masEndpoint = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:8081/";
        description = "Internal MAS endpoint URL for Synapse ↔ MAS communication.";
      };
    };

    autoCompressor = {
      enable = lib.mkEnableOption "periodic Synapse state compressor (reclaims DB space)";

      interval = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "systemd calendar expression for how often to run the compressor.";
        example = "daily";
      };

      chunksToCompress = lib.mkOption {
        type = lib.types.ints.positive;
        default = 500;
        description = "Number of state groups to work on per run.";
      };

      chunkSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 500;
        description = "Number of state groups per compression chunk.";
      };
    };

    vacuumTimer = {
      enable = lib.mkEnableOption "periodic VACUUM ANALYZE on the Synapse DB";

      interval = lib.mkOption {
        type = lib.types.str;
        default = "monthly";
        description = "systemd calendar expression for how often to run VACUUM ANALYZE.";
        example = "weekly";
      };
    };

    dbSizeLogger = {
      enable = lib.mkEnableOption "periodic DB size logging to the journal";

      interval = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "systemd calendar expression for how often to log DB size.";
      };
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Synapse settings merged into the configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      postgresql = lib.mkIf cfg.database.createLocally {
        enable = true;

        initialScript = pkgs.writeText "synapse-init.sql" ''
          CREATE ROLE "matrix-synapse" WITH LOGIN;
          CREATE DATABASE "matrix-synapse"
            WITH OWNER "matrix-synapse"
                 TEMPLATE template0
                 LC_COLLATE = "C"
                 LC_CTYPE = "C";
        '';

        settings = {
          autovacuum_vacuum_scale_factor = 0.05;
          autovacuum_analyze_scale_factor = 0.02;
          autovacuum_naptime = "30s";
          autovacuum_max_workers = 4;
          autovacuum_vacuum_cost_limit = 2000;
        };
      };

      matrix-synapse = {
        enable = true;
        inherit (cfg) dataDir;

        extras = [ "postgres" ] ++ lib.optionals cfg.authDelegation.enable [ "oidc" ];

        inherit (cfg) extraConfigFiles;

        settings = lib.mkMerge [
          {
            server_name = cfg.serverName;

            public_baseurl =
              if cfg.publicBaseUrl != null then
                cfg.publicBaseUrl
              else if cfg.reverseProxy.enable && cfg.reverseProxy.domain != null then
                "https://${cfg.reverseProxy.domain}"
              else
                null;

            listeners = [
              {
                inherit (cfg) port;
                bind_addresses = [ "0.0.0.0" ];
                type = "http";
                tls = false;
                x_forwarded = true;
                resources = [
                  {
                    names = [
                      "client"
                      "federation"
                    ];
                    compress = false;
                  }
                ];
              }
            ];

            url_preview_enabled = cfg.urlPreview.enable;

            enable_registration = if cfg.authDelegation.enable then lib.mkForce false else lib.mkDefault true;
            report_stats = false;

            # Allow VMs to override this when they handle well-known via Nginx
            serve_server_wellknown = lib.mkDefault true;
          }
          (lib.optionalAttrs cfg.database.createLocally {
            database = {
              name = "psycopg2";
              args = {
                user = "matrix-synapse";
                database = "matrix-synapse";
                host = "/run/postgresql";
                cp_min = 5;
                cp_max = 10;
              };
            };
          })
          (lib.optionalAttrs cfg.urlPreview.enable {
            url_preview_ip_range_blacklist = [
              "127.0.0.0/8"
              "10.0.0.0/8"
              "172.16.0.0/12"
              "192.168.0.0/16"
              "100.64.0.0/10"
              "192.0.0.0/24"
              "169.254.0.0/16"
              "192.88.99.0/24"
              "198.18.0.0/15"
              "192.0.2.0/24"
              "198.51.100.0/24"
              "203.0.113.0/24"
              "224.0.0.0/4"
              "::1/128"
              "fe80::/10"
              "fc00::/7"
              "2001:db8::/32"
              "ff00::/8"
              "fec0::/10"
            ];
          })
          # Delegate authentication to MAS. The shared secret is injected
          # at runtime via extraConfigFiles.
          (lib.optionalAttrs cfg.authDelegation.enable {
            matrix_authentication_service = {
              enabled = true;
              endpoint = cfg.authDelegation.masEndpoint;
            };
          })
          cfg.settings
        ];
      };

      traefik.dynamic.files.matrix-synapse = traefikLib.mkTraefikDynamicConfig {
        name = "matrix-synapse";
        inherit cfg config;
        inherit (cfg) port;
        defaultMiddlewares = [ "security-headers" ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    systemd = {
      timers = {
        synapse-auto-compressor = lib.mkIf cfg.autoCompressor.enable {
          description = "Run Synapse state compressor periodically";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.autoCompressor.interval;
            Persistent = true;
            RandomizedDelaySec = "4h";
          };
        };

        matrix-synapse-vacuum = lib.mkIf (cfg.vacuumTimer.enable && cfg.database.createLocally) {
          description = "Run VACUUM ANALYZE on the Synapse DB periodically";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.vacuumTimer.interval;
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };

        matrix-synapse-db-size = lib.mkIf (cfg.dbSizeLogger.enable && cfg.database.createLocally) {
          description = "Log Synapse DB size to the journal periodically";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.dbSizeLogger.interval;
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };
      };

      services = {
        synapse-auto-compressor = lib.mkIf cfg.autoCompressor.enable {
          description = "Compress Synapse room state to reclaim database space";
          after = [
            "matrix-synapse.service"
            "postgresql.service"
          ];
          requires = [ "postgresql.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = "matrix-synapse";
          };
          script = ''
            ${pkgs.rust-synapse-compress-state}/bin/synapse_auto_compressor \
              -p ${lib.escapeShellArg "host=/run/postgresql user=matrix-synapse dbname=matrix-synapse"} \
              -c ${toString cfg.autoCompressor.chunksToCompress} \
              -n ${toString cfg.autoCompressor.chunkSize}
          '';
        };

        matrix-synapse-vacuum = lib.mkIf (cfg.vacuumTimer.enable && cfg.database.createLocally) {
          description = "VACUUM ANALYZE the Synapse PostgreSQL database";
          after = [
            "matrix-synapse.service"
            "postgresql.service"
          ];
          requires = [ "postgresql.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = "matrix-synapse";
          };
          script = ''
            ${config.services.postgresql.package}/bin/psql \
              --no-psqlrc \
              --set=ON_ERROR_STOP=1 \
              -h /run/postgresql \
              -d matrix-synapse \
              -c "VACUUM (ANALYZE);"
          '';
        };

        matrix-synapse-db-size = lib.mkIf (cfg.dbSizeLogger.enable && cfg.database.createLocally) {
          description = "Log Synapse PostgreSQL database size to the journal";
          after = [ "postgresql.service" ];
          requires = [ "postgresql.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = "matrix-synapse";
          };
          script = ''
            ${config.services.postgresql.package}/bin/psql \
              --no-psqlrc \
              --set=ON_ERROR_STOP=1 \
              -h /run/postgresql \
              -d matrix-synapse \
              -c "SELECT pg_size_pretty(pg_database_size('matrix-synapse')) AS db_size;" \
              -c "SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) AS total_size FROM pg_class WHERE relkind = 'r' ORDER BY pg_total_relation_size(oid) DESC LIMIT 10;"
          '';
        };

        matrix-synapse-pg-tuning = lib.mkIf cfg.database.createLocally {
          description = "Apply per-table autovacuum settings for Synapse hot tables";
          wantedBy = [ "multi-user.target" ];
          after = [
            "matrix-synapse.service"
            "postgresql.service"
          ];
          requires = [ "postgresql.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "matrix-synapse";
          };
          script = ''
            ${config.services.postgresql.package}/bin/psql \
              --no-psqlrc \
              --set=ON_ERROR_STOP=1 \
              -h /run/postgresql \
              -d matrix-synapse \
              -c "ALTER TABLE state_groups_state SET (autovacuum_vacuum_scale_factor = 0.02);" \
              -c "ALTER TABLE event_json SET (autovacuum_vacuum_scale_factor = 0.05);" \
              -c "ALTER TABLE event_edges SET (autovacuum_vacuum_scale_factor = 0.05);" \
              -c "ALTER TABLE event_auth SET (autovacuum_vacuum_scale_factor = 0.05);" \
              -c "ALTER TABLE events SET (autovacuum_vacuum_scale_factor = 0.05);"
          '';
        };
      };
    };

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.matrix-synapse.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.matrix-synapse.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.authDelegation.enable || cfg.extraConfigFiles != [ ];
        message = "sys.services.matrix-synapse.extraConfigFiles must contain at least one secrets file when authDelegation is enabled";
      }
      {
        assertion = !cfg.autoCompressor.enable || cfg.database.createLocally;
        message = "sys.services.matrix-synapse.autoCompressor requires database.createLocally = true (local PostgreSQL)";
      }
      {
        assertion = !cfg.vacuumTimer.enable || cfg.database.createLocally;
        message = "sys.services.matrix-synapse.vacuumTimer requires database.createLocally = true";
      }
      {
        assertion = !cfg.dbSizeLogger.enable || cfg.database.createLocally;
        message = "sys.services.matrix-synapse.dbSizeLogger requires database.createLocally = true";
      }
      (traefikLib.mkCfTunnelAssertion {
        name = "matrix-synapse";
        inherit cfg;
      })
    ];
  };
}
