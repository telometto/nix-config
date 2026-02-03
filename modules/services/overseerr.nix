{ lib, config, ... }:
let
  cfg = config.sys.services.overseerr;
in
{
  options.sys.services.overseerr = {
    enable = lib.mkEnableOption "Overseerr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
      description = "Port where Overseerr listens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Traefik reverse proxy configuration for Overseerr.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Domain for Overseerr (e.g., "overseerr.example.com").
          This creates a router that matches requests to this domain and forwards to Overseerr.
          Required when reverseProxy.enable = true.
        '';
        example = "overseerr.example.com";
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
    services.overseerr = {
      enable = lib.mkDefault true;
      inherit (cfg) openFirewall port;
    };

    services.traefik.dynamicConfigOptions =
      lib.mkIf (cfg.reverseProxy.enable && config.services.traefik.enable or false)
        {
          http = {
            middlewares.overseerr-headers = {
              headers = {
                customResponseHeaders = {
                  X-Content-Type-Options = "nosniff";
                  X-Frame-Options = "SAMEORIGIN";
                  X-XSS-Protection = "1; mode=block";
                  Referrer-Policy = "no-referrer-when-downgrade";
                  Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
                };

                contentSecurityPolicy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://plex.tv https://*.plex.tv https://*.plex.direct wss://*.plex.direct; frame-src https://app.plex.tv;";
              };
            };

            routers.overseerr = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "overseerr";
              entryPoints = [ "web" ];
              middlewares = [ "overseerr-headers" ];
            };

            services.overseerr.loadBalancer = {
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
        message = "sys.services.overseerr.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.overseerr.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.overseerr.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
