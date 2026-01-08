{ lib, config, ... }:
let
  cfg = config.sys.services.gitea;
in
{
  options.sys.services.gitea = {
    enable = lib.mkEnableOption "Gitea";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/gitea";
    };

    repositoryRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to git repositories. Defaults to stateDir/repositories.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [
          "sqlite3"
          "mysql"
          "postgres"
        ];
        default = "postgres";
      };

      createDatabase = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };

    lfs.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    disableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "git.example.com";
      };

      cfTunnel.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional Gitea settings (see https://docs.gitea.io/en-us/config-cheat-sheet/).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.gitea = {
      enable = true;
      inherit (cfg) stateDir;
      repositoryRoot = lib.mkIf (cfg.repositoryRoot != null) cfg.repositoryRoot;

      database = {
        inherit (cfg.database) type createDatabase;
      };

      lfs.enable = cfg.lfs.enable;

      settings = lib.mkMerge [
        {
          server = {
            HTTP_PORT = cfg.port;
            ROOT_URL = lib.mkIf (
              cfg.reverseProxy.enable && cfg.reverseProxy.domain != null
            ) "https://${cfg.reverseProxy.domain}/";
          };

          service.DISABLE_REGISTRATION = cfg.disableRegistration;

          session.COOKIE_SECURE = lib.mkIf cfg.reverseProxy.enable true;
        }
        cfg.settings
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    services.traefik.dynamicConfigOptions =
      lib.mkIf (cfg.reverseProxy.enable && config.services.traefik.enable or false)
        {
          http = {
            routers.gitea = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "gitea";
              entryPoints = [ "web" ];
              middlewares = [
                "security-headers"
                "gitea-xfp-https"
              ];
            };

            services.gitea.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
            };

            middlewares."gitea-xfp-https".headers.customRequestHeaders = {
              "X-Forwarded-Proto" = "https";
            };
          };
        };

    sys.services.cloudflared.ingress =
      lib.mkIf
        (
          cfg.reverseProxy.cfTunnel.enable
          && cfg.reverseProxy.enable
          && config.sys.services.cloudflared.enable or false
        )
        {
          "${cfg.reverseProxy.domain}" = "http://localhost:80";
        };

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.gitea.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.gitea.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.gitea.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
