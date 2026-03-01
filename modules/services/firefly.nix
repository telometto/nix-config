{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.firefly;
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.firefly = {
    enable = lib.mkEnableOption "Firefly III personal finance manager";

    enableNginx = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Nginx virtual host for PHP-FPM";
    };

    virtualHost = lib.mkOption {
      type = lib.types.str;
      default = "firefly";
      description = "Nginx virtual host name for Firefly III";
    };

    appKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = config.sys.secrets.fireflyAppKeyFile or null;
      description = "Path to file containing the APP_KEY (32-char base64-encoded key)";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 80;
      description = "Nginx listen port for the Firefly III virtual host";
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Create a local PostgreSQL database for Firefly III";
      };
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra Firefly III .env settings";
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "firefly"; };
  };

  config = lib.mkIf cfg.enable {
    services = {
      postgresql = lib.mkIf cfg.database.createLocally {
        enable = true;

        initialScript = pkgs.writeText "firefly-init.sql" ''
          CREATE ROLE "firefly-iii" WITH LOGIN;
          CREATE DATABASE "firefly-iii"
            WITH OWNER "firefly-iii"
                 TEMPLATE template0
                 LC_COLLATE = "C"
                 LC_CTYPE = "C";
        '';
      };

      firefly-iii = {
        enable = true;

        inherit (cfg) enableNginx virtualHost;

        settings = {
          APP_ENV = "local";
          APP_KEY_FILE = lib.mkIf (cfg.appKeyFile != null) cfg.appKeyFile;
          DB_CONNECTION = "pgsql";
        }
        // {
          DB_HOST = "/run/postgresql";
          DB_DATABASE = "firefly-iii";
          DB_USERNAME = "firefly-iii";
          DB_PORT = 5432;
        }
        // lib.optionalAttrs (cfg.reverseProxy.enable && cfg.reverseProxy.domain != null) {
          APP_URL = "https://${cfg.reverseProxy.domain}";
          TRUSTED_PROXIES = "**";
        }
        // cfg.settings;
      };

      traefik.dynamic.files.firefly = traefikLib.mkTraefikDynamicConfig {
        name = "firefly";
        inherit cfg config;
        inherit (cfg) port;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.firefly.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      (traefikLib.mkCfTunnelAssertion {
        name = "firefly";
        inherit cfg;
      })
    ];
  };
}
