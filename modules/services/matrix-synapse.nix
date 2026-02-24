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
      };

      matrix-synapse = {
        enable = true;
        inherit (cfg) dataDir;

        extras = [ "postgres" ];

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

            enable_registration = false;
            report_stats = false;

            # Handles /.well-known/matrix/server so federation works without
            # external web server config on the bare domain
            serve_server_wellknown = true;
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

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.matrix-synapse.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.matrix-synapse.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      (traefikLib.mkCfTunnelAssertion {
        name = "matrix-synapse";
        inherit cfg;
      })
    ];
  };
}
