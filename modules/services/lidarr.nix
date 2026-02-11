{ lib, config, ... }:
let
  cfg = config.sys.services.lidarr or { };
in
{
  options.sys.services.lidarr = {
    enable = lib.mkEnableOption "Lidarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8686;
      description = "Port where Lidarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/lidarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Lidarr.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "lidarr.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "lidarr.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/lidarr";
        description = "URL path prefix for Lidarr.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Lidarr.";
      };

      extraMiddlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional Traefik middlewares to apply.";
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
  };

  config = lib.mkIf cfg.enable {
    services.lidarr = {
      enable = true;
      inherit (cfg) dataDir openFirewall;
      settings.server.port = cfg.port;
    };

    # Disable DynamicUser to prevent conflict with volume-mounted dataDir
    systemd.services.lidarr.serviceConfig = {
      DynamicUser = lib.mkForce false;
      SupplementaryGroups = [ "users" ];
      UMask = "002";
    };

    services.traefik.dynamicConfigOptions =
      lib.mkIf
        (
          cfg.reverseProxy.enable
          && cfg.reverseProxy.domain != null
          && config.services.traefik.enable or false
        )
        {
          http = {
            routers.lidarr = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "lidarr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ] ++ cfg.reverseProxy.extraMiddlewares;
            };

            services.lidarr.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
            };
          };
        };

    assertions = [
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.lidarr.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
