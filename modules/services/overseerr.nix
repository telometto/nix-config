{ lib, config, ... }:
let
  cfg = config.sys.services.overseerr or { };
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
        default = true;
        description = "Enable Traefik reverse proxy configuration for Overseerr.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "overseerr.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "overseerr.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/overseerr";
        description = "URL path prefix for Overseerr.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Overseerr.";
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
    services.overseerr = {
      enable = true;
      inherit (cfg) port openFirewall;
    };

    services.traefik.dynamic.files.overseerr =
      lib.mkIf
        (
          cfg.reverseProxy.enable
          && cfg.reverseProxy.domain != null
          && config.services.traefik.enable or false
        )
        {
          settings = {
            http = {
              routers.overseerr = {
                rule = "Host(`${cfg.reverseProxy.domain}`)";
                service = "overseerr";
                entryPoints = [ "web" ];
                middlewares = [ "security-headers" ] ++ cfg.reverseProxy.extraMiddlewares;
              };

              services.overseerr.loadBalancer = {
                servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
                passHostHeader = true;
              };
            };
          };
        };

    assertions = [
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.overseerr.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
