{ lib, config, ... }:
let
  cfg = config.sys.services.gitea;
in
{
  options.sys.services.gitea = {
    enable = lib.mkEnableOption "Gitea";

    httpPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Optional override for the Gitea HTTP port (falls back to upstream default when null).";
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [
          "sqlite3"
          "mysql"
          "postgres"
        ];
        default = "postgres";
        description = "Database engine to use.";
      };

      createDatabase = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to create a local database automatically.";
      };
    };

    lfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Git LFS support.";
      };

      contentDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Where to store LFS files (uses upstream default when null).";
      };
    };

    disableRegistration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable user registration. The first registered user will be the administrator.";
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Traefik reverse proxy configuration for Gitea.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Domain for Gitea (e.g., "git.example.com").
          This creates a router that matches requests to this domain and forwards to Gitea.
          Required when reverseProxy.enable = true.
        '';
        example = "git.example.com";
      };

      cfTunnel = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable Cloudflare Tunnel ingress for this service.
            When enabled, automatically adds this service to the Cloudflare Tunnel ingress configuration.
            Requires reverseProxy.enable = true and reverseProxy.domain to be set.
          '';
        };
      };
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Additional Gitea configuration.
        Refer to https://docs.gitea.io/en-us/config-cheat-sheet/ for details.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    let
      giteaPort = cfg.httpPort or 3000;
      traefikEnabled = config.services.traefik.enable or false;
      cloudflaredEnabled = config.sys.services.cloudflared.enable or false;
      reverseProxyEnabled = cfg.reverseProxy.enable && cfg.reverseProxy.domain != null;
    in
    {
      services.gitea = lib.mkMerge [
        {
          enable = true;

          database = {
            inherit (cfg.database) type createDatabase;
          };

          lfs = lib.mkIf cfg.lfs.enable (
            lib.mkMerge [
              { enable = true; }
              (lib.mkIf (cfg.lfs.contentDir != null) { contentDir = cfg.lfs.contentDir; })
            ]
          );

          settings = lib.mkMerge [
            { service.DISABLE_REGISTRATION = cfg.disableRegistration; }
            (lib.mkIf reverseProxyEnabled {
              server.ROOT_URL = "https://${cfg.reverseProxy.domain}/";
              session.COOKIE_SECURE = true;
            })
            cfg.settings
          ];
        }
        (lib.optionalAttrs (cfg.httpPort != null) { httpPort = cfg.httpPort; })
      ];

      services.traefik.dynamicConfigOptions = lib.mkIf (reverseProxyEnabled && traefikEnabled) {
        http = {
          routers.gitea = {
            rule = "Host(`${cfg.reverseProxy.domain}`)";
            service = "gitea";
            entryPoints = [ "web" ];
            middlewares = [ "security-headers" ];
          };

          services.gitea.loadBalancer = {
            servers = [ { url = "http://localhost:${toString giteaPort}"; } ];
            passHostHeader = true;
          };
        };
      };

      sys.services.cloudflared.ingress =
        lib.mkIf (cfg.reverseProxy.cfTunnel.enable && reverseProxyEnabled && cloudflaredEnabled)
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
    }
  );
}
