{ lib, config, ... }:
let
  cfg = config.sys.services.prowlarr or { };
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
      default = "/var/lib/prowlarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Prowlarr.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "prowlarr.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "prowlarr.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/prowlarr";
        description = "URL path prefix for Prowlarr.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Prowlarr.";
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
    services.prowlarr = {
      enable = true;
      inherit (cfg) dataDir openFirewall;
      settings.server.port = cfg.port;
    };

    # Disable DynamicUser to prevent conflict with volume-mounted dataDir
    systemd.services.prowlarr.serviceConfig = {
      DynamicUser = lib.mkForce false;
    };

    services.traefik.dynamic.files.prowlarr =
      lib.mkIf
        (
          cfg.reverseProxy.enable
          && cfg.reverseProxy.domain != null
          && config.services.traefik.enable or false
        )
        {
          settings = {
            http = {
              routers.prowlarr = {
                rule = "Host(`${cfg.reverseProxy.domain}`)";
                service = "prowlarr";
                entryPoints = [ "web" ];
                middlewares = [ "security-headers" ] ++ cfg.reverseProxy.extraMiddlewares;
              };

              services.prowlarr.loadBalancer = {
                servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
                passHostHeader = true;
              };
            };
          };
        };

    assertions = [
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.prowlarr.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
