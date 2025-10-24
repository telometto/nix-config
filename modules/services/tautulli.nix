{ lib, config, ... }:
let
  cfg = config.telometto.services.tautulli;
in
{
  options.telometto.services.tautulli = {
    enable = lib.mkEnableOption "Tautulli";

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

      port = lib.mkOption {
        type = lib.types.port;
        default = 8181;
        description = "Port where Tautulli listens.";
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
      inherit (cfg) dataDir configFile openFirewall;
    };

    # Configure Traefik reverse proxy if enabled
    # Using standard NixOS services.traefik.dynamicConfigOptions
    services.traefik.dynamicConfigOptions =
      lib.mkIf (cfg.reverseProxy.enable && config.services.traefik.enable or false)
        {
          http = {
            # Router: matches the domain and forwards to the service
            # Using 'web' (HTTP) entrypoint since Cloudflare Tunnel handles HTTPS
            routers.tautulli = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "tautulli";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            # Service: points to Tautulli backend
            services.tautulli.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.reverseProxy.port}"; } ];
              passHostHeader = true;
            };
          };
        };

    # Configure Cloudflare Tunnel ingress if enabled
    telometto.services.cloudflared.ingress =
      lib.mkIf
        (
          cfg.reverseProxy.cfTunnel.enable
          && cfg.reverseProxy.enable
          && config.telometto.services.cloudflared.enable or false
        )
        {
          "${cfg.reverseProxy.domain}" = "http://localhost:80";
        };

    # Validate configuration
    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "telometto.services.tautulli.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "telometto.services.tautulli.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "telometto.services.tautulli.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
