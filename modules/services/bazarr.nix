{ lib, config, ... }:
let
  cfg = config.sys.services.bazarr or { };
in
{
  options.sys.services.bazarr = {
    enable = lib.mkEnableOption "Bazarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 6767;
      description = "Port where Bazarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/bazarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Bazarr.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "bazarr.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "bazarr.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/bazarr";
        description = "URL path prefix for Bazarr.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Bazarr.";
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
    services.bazarr = {
      enable = true;
      listenPort = cfg.port;
      inherit (cfg) dataDir openFirewall;
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
            routers.bazarr = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "bazarr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ] ++ cfg.reverseProxy.extraMiddlewares;
            };

            services.bazarr.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
            };
          };
        };

    assertions = [
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.bazarr.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
