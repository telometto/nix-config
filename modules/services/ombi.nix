{ lib, config, ... }:
let
  cfg = config.sys.services.ombi or { };
in
{
  options.sys.services.ombi = {
    enable = lib.mkEnableOption "Ombi";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Port where Ombi listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/ombi";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Ombi.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "ombi.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "ombi.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/ombi";
        description = "URL path prefix for Ombi.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Ombi.";
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
    services.ombi = {
      enable = true;
      inherit (cfg) dataDir openFirewall port;
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
            routers.ombi = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "ombi";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            services.ombi.loadBalancer = {
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
          && cfg.reverseProxy.domain != null
          && config.sys.services.cloudflared.enable or false
        )
        {
          "${cfg.reverseProxy.domain}" = "http://localhost:80";
        };

    assertions = [
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.ombi.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
