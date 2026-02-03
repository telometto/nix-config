{ lib, config, ... }:
let
  cfg = config.sys.services.prowlarr;
in
{
  options.sys.services.prowlarr = {
    enable = lib.mkEnableOption "Prowlarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9696;
      description = "Port where Prowlarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/prowlarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Traefik reverse proxy configuration for Prowlarr.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Domain for Prowlarr (e.g., "prowlarr.example.com").
          This creates a router that matches requests to this domain and forwards to Prowlarr.
          Required when reverseProxy.enable = true.
        '';
        example = "prowlarr.example.com";
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
    services = {
      prowlarr = {
        enable = lib.mkDefault true;
        inherit (cfg) dataDir openFirewall;
      };

      prowlarr.settings.server.port = cfg.port;

      traefik.dynamicConfigOptions =
        lib.mkIf (cfg.reverseProxy.enable && config.services.traefik.enable or false)
          {
            http = {
              routers.prowlarr = {
                rule = "Host(`${cfg.reverseProxy.domain}`)";
                service = "prowlarr";
                entryPoints = [ "web" ];
                middlewares = [ "security-headers" ];
              };

              services.prowlarr.loadBalancer = {
                servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
                passHostHeader = true;
              };
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
        message = "sys.services.prowlarr.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.prowlarr.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.prowlarr.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
