{ lib, config, ... }:
let
  cfg = config.sys.services.sonarr or { };
in
{
  options.sys.services.sonarr = {
    enable = lib.mkEnableOption "Sonarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8989;
      description = "Port where Sonarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sonarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Sonarr.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "sonarr.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "sonarr.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/sonarr";
        description = "URL path prefix for Sonarr.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Sonarr.";
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
    services.sonarr = {
      enable = true;
      inherit (cfg) dataDir openFirewall;
      settings.server.port = cfg.port;
    };

    # Disable DynamicUser to prevent conflict with volume-mounted dataDir
    systemd.services.sonarr.serviceConfig = {
      DynamicUser = lib.mkForce false;
      UMask = "002";
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
            routers.sonarr = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "sonarr";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ] ++ cfg.reverseProxy.extraMiddlewares;
            };

            services.sonarr.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
            };
          };
        };

    assertions = [
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.sonarr.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
