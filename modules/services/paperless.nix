{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.paperless;
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.paperless = {
    enable = lib.mkEnableOption "Paperless-ngx document management";

    address = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 28981;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = config.sys.secrets.paperlessKeyFile or null;
      description = "Path to file containing the superuser password";
    };

    database.createLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Configure local PostgreSQL for Paperless";
    };

    configureTika = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Tika and Gotenberg for Office/email document processing";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.sys.secrets.paperlessSecretKeyFile or null;
      description = "Path to file containing the secret key for session tokens";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra PAPERLESS_* environment variable settings";
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "paperless"; };
  };

  config = lib.mkIf cfg.enable {
    services = {
      postgresql = lib.mkIf cfg.database.createLocally {
        enable = true;

        initialScript = pkgs.writeText "paperless-init.sql" ''
          CREATE ROLE "paperless" WITH LOGIN;
          CREATE DATABASE "paperless"
            WITH OWNER "paperless"
                 TEMPLATE template0
                 LC_COLLATE = "C"
                 LC_CTYPE = "C";
        '';
      };

      paperless = {
        enable = true;
        inherit (cfg)
          address
          port
          passwordFile
          ;

        database.createLocally = cfg.database.createLocally;
        inherit (cfg) configureTika;

        settings = {
          PAPERLESS_OCR_LANGUAGE = lib.mkDefault "eng";
          PAPERLESS_TIME_ZONE = lib.mkDefault (config.time.timeZone or "UTC");
        }
        // lib.optionalAttrs (cfg.reverseProxy.enable && cfg.reverseProxy.domain != null) {
          PAPERLESS_URL = "https://${cfg.reverseProxy.domain}";
        }
        // lib.optionalAttrs (cfg.secretKeyFile != null) {
          PAPERLESS_SECRET_KEY = cfg.secretKeyFile;
        }
        // cfg.settings;
      };

      traefik.dynamic.files.paperless = traefikLib.mkTraefikDynamicConfig {
        name = "paperless";
        inherit cfg config;
        inherit (cfg) port;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.paperless.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      (traefikLib.mkCfTunnelAssertion {
        name = "paperless";
        inherit cfg;
      })
    ];
  };
}
