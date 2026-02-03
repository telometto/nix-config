{ lib, config, ... }:
let
  cfg = config.sys.services.readarr;
in
{
  options.sys.services.readarr = {
    enable = lib.mkEnableOption "Readarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "Port where Readarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/readarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Traefik reverse proxy configuration for Readarr.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Domain for Readarr (e.g., "readarr.example.com").
          This creates a router that matches requests to this domain and forwards to Readarr.
          Required when reverseProxy.enable = true.
        '';
        example = "readarr.example.com";
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
      readarr = {
        enable = lib.mkDefault true;
        inherit (cfg) dataDir openFirewall;
      };

      readarr.settings.server.port = cfg.port;

      traefik.dynamicConfigOptions =
        lib.mkIf (cfg.reverseProxy.enable && config.services.traefik.enable or false)
          {
            http = {
              routers.readarr = {
                rule = "Host(`${cfg.reverseProxy.domain}`)";
                service = "readarr";
                entryPoints = [ "web" ];
                middlewares = [ "security-headers" ];
              };

              services.readarr.loadBalancer = {
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
        message = "sys.services.readarr.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.readarr.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.readarr.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
