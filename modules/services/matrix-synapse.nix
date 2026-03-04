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
          MAS handles authentication flows via MSC3861.
          The MSC3861 secrets (client_secret, admin_token) must be injected
          at runtime via extraConfigFiles.
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
          # Non-secret MSC3861 fields — client_secret and admin_token
          # are injected at runtime via extraConfigFiles.
          (lib.optionalAttrs cfg.authDelegation.enable {
            experimental_features.msc3861 = {
              enabled = true;
              issuer = cfg.authDelegation.issuer;
              client_id = cfg.authDelegation.clientId;
              client_auth_method = cfg.authDelegation.clientAuthMethod;
            }
            // lib.optionalAttrs (cfg.authDelegation.accountManagementUrl != null) {
              account_management_url = cfg.authDelegation.accountManagementUrl;
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
        assertion = !cfg.authDelegation.enable || cfg.authDelegation.issuer != "";
        message = "sys.services.matrix-synapse.authDelegation.issuer must be set when authDelegation is enabled";
      }
      {
        assertion = !cfg.authDelegation.enable || cfg.extraConfigFiles != [ ];
        message = "sys.services.matrix-synapse.extraConfigFiles must contain at least one secrets file when authDelegation is enabled";
      }
      (traefikLib.mkCfTunnelAssertion {
        name = "matrix-synapse";
        inherit cfg;
      })
    ];
  };
}
