{ lib, config, ... }:
let
  cfg = config.sys.services.radarr or { };
in
{
  options.sys.services.radarr = {
    enable = lib.mkEnableOption "Radarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7878;
      description = "Port where Radarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/radarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Radarr.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "radarr.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "radarr.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/radarr";
        description = "URL path prefix for Radarr.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Radarr.";
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
    services.radarr = {
      enable = true;
      inherit (cfg) dataDir openFirewall;
      settings.server.port = cfg.port;
    };

    # Disable DynamicUser to prevent conflict with volume-mounted dataDir
    systemd.services.radarr.serviceConfig = {
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
            routers.radarr = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "radarr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ] ++ cfg.reverseProxy.extraMiddlewares;
            };

            services.radarr.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
            };
          };
        };

    assertions = [
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.radarr.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
