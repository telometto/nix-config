{
  lib,
  config,
  ...
}:
let
  cfg = config.sys.services.mealie;
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.mealie = {
    enable = lib.mkEnableOption "Mealie recipe manager and meal planner";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Internal port Mealie listens on. nginx fronts on the external VM port.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address Mealie binds to.";
    };

    database.createLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Configure a local PostgreSQL database for Mealie.";
    };

    credentialsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file in EnvironmentFile format (systemd.exec(5)) containing
        sensitive Mealie settings, e.g. SECRET_KEY=<value>.
      '';
      example = "/run/secrets/mealie-credentials";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra Mealie environment variable settings passed through to services.mealie.settings.";
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "mealie"; };
  };

  config = lib.mkIf cfg.enable {
    services = {
      mealie = {
        enable = true;

        inherit (cfg) port listenAddress credentialsFile;

        database.createLocally = cfg.database.createLocally;

        settings = {
          ALLOW_SIGNUP = "false";
        }
        // lib.optionalAttrs (cfg.reverseProxy.enable && cfg.reverseProxy.domain != null) {
          BASE_URL = "https://${cfg.reverseProxy.domain}";
        }
        // cfg.settings;
      };

      traefik.dynamic.files.mealie = traefikLib.mkTraefikDynamicConfig {
        name = "mealie";
        inherit cfg config;
        inherit (cfg) port;
      };
    };

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.mealie.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      (traefikLib.mkCfTunnelAssertion {
        name = "mealie";
        inherit cfg;
      })
    ];
  };
}
