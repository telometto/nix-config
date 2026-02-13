{ lib, config, ... }:
let
  cfg = config.sys.services.tautulli;
in
{
  options.sys.services.tautulli = {
    enable = lib.mkEnableOption "Tautulli";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8181;
      description = "Port where Tautulli listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/tautulli";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/tautulli/config.ini";
      description = "This should be set so that config isn't reset every time the app (re)starts.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Traefik reverse proxy configuration for Tautulli.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Domain for Tautulli (e.g., "tautulli.example.com").
          This creates a router that matches requests to this domain and forwards to Tautulli.
          Required when reverseProxy.enable = true.
        '';
        example = "tautulli.example.com";
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
    services.tautulli = {
      enable = lib.mkDefault true;
      inherit (cfg)
        dataDir
        configFile
        openFirewall
        port
        ;
    };

    services.traefik.dynamic.files.tautulli = lib.mkIf
      (cfg.reverseProxy.enable && config.services.traefik.enable or false)
      {
        settings = {
          http = {
            middlewares = {
              # Relaxed headers for Tautulli (requires Plex OAuth)
              tautulli-headers = {
                headers = {
                  customResponseHeaders = {
                    X-Content-Type-Options = "nosniff";
                    X-Frame-Options = "SAMEORIGIN";
                    X-XSS-Protection = "1; mode=block";
                    Referrer-Policy = "no-referrer-when-downgrade";
                    Permissions-Policy = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=(), fullscreen=(self), picture-in-picture=(self)";
                  };

                  # Relaxed CSP to allow Plex OAuth flow
                  contentSecurityPolicy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://plex.tv https://*.plex.tv https://*.plex.direct wss://*.plex.direct; frame-src https://app.plex.tv;";
                };
              };
            };

            routers.tautulli = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "tautulli";
              entryPoints = [ "web" ];
              middlewares = [ "tautulli-headers" ];
            };

            services.tautulli.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
            };
          };
        };
      };

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.tautulli.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.tautulli.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.tautulli.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
