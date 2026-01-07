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
      description = "Port where Gitea web interface listens.";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "Port where Gitea SSH server listens.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "gitea";
      description = "User account under which Gitea runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "gitea";
      description = "Group under which Gitea runs.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/gitea";
      description = "Gitea data directory.";
    };

    repositoryRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/gitea/repositories";
      description = "Path to the git repositories.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for Gitea web and SSH ports.";
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [ "sqlite3" "mysql" "postgres" ];
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
        type = lib.types.str;
        default = "${cfg.stateDir}/lfs";
        description = "Where to store LFS files.";
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

  config = lib.mkIf cfg.enable {
    services.gitea = {
      enable = true;
      inherit (cfg)
        user
        group
        stateDir
        repositoryRoot
        ;

      database = {
        inherit (cfg.database) type createDatabase;
      };

      lfs = lib.mkIf cfg.lfs.enable {
        enable = true;
        contentDir = cfg.lfs.contentDir;
      };

      settings = lib.mkMerge [
        {
          server = {
            HTTP_PORT = cfg.port;
            SSH_PORT = cfg.sshPort;
            ROOT_URL = lib.mkIf (cfg.reverseProxy.enable && cfg.reverseProxy.domain != null)
              "https://${cfg.reverseProxy.domain}/";
          };

          service = {
            DISABLE_REGISTRATION = cfg.disableRegistration;
          };

          session = {
            COOKIE_SECURE = lib.mkIf cfg.reverseProxy.enable true;
          };
        }
        cfg.settings
      ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port cfg.sshPort ];
    };

    services.traefik.dynamicConfigOptions =
      lib.mkIf (cfg.reverseProxy.enable && config.services.traefik.enable or false)
        {
          http = {
            routers.gitea = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "gitea";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            services.gitea.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
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
