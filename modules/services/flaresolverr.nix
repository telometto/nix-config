{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.flaresolverr;
in
{
  options.sys.services.flaresolverr = {
    enable = lib.mkEnableOption "FlareSolverr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8191;
      description = "Port where FlareSolverr listens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Traefik reverse proxy configuration for FlareSolverr.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Domain for FlareSolverr (e.g., "flaresolverr.example.com").
          This creates a router that matches requests to this domain and forwards to FlareSolverr.
          Required when reverseProxy.enable = true.
        '';
        example = "flaresolverr.example.com";
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

        tunnelId = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Cloudflare Tunnel ID to use for this service.
            If not set, uses services.cloudflared.tunnelId.
          '';
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.flaresolverr = {
      enable = lib.mkDefault true;
      inherit (cfg) port openFirewall;
    };

    services.traefik.dynamicConfigOptions =
      lib.mkIf (cfg.reverseProxy.enable && config.services.traefik.enable or false)
        {
          http = {
            routers.flaresolverr = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "flaresolverr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            services.flaresolverr.loadBalancer = {
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
        message = "sys.services.flaresolverr.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.flaresolverr.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.flaresolverr.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
