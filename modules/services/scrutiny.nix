{ lib, config, ... }:
let
  cfg = config.sys.services.scrutiny or { };
in
{
  options.sys.services.scrutiny = {
    enable = lib.mkEnableOption "Scrutiny SMART monitoring";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8072;
      description = "Port for Scrutiny web interface";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for Scrutiny";
    };

    collectorSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Additional collector settings for Scrutiny.
        See https://github.com/AnalogJ/scrutiny/blob/master/example.collector.yaml
      '';
      example = lib.literalExpression ''
        {
          devices = [
            {
              device = "/dev/sda";
              type = [ "sat" ];
            }
          ];
        }
      '';
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Scrutiny.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional domain for hostname-based routing (e.g., "scrutiny.example.com").
          If set, creates a separate router for this domain with pathPrefix = "/".
          This is useful for Cloudflare Tunnel with dedicated subdomains.
        '';
        example = "scrutiny.example.com";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/scrutiny";
        description = "URL path prefix for Scrutiny.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Scrutiny.";
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
    services.scrutiny = {
      enable = lib.mkDefault true;

      inherit (cfg) openFirewall;

      settings.web.listen.port = cfg.port;

      collector = lib.mkIf (cfg.collectorSettings != { }) {
        settings = cfg.collectorSettings;
      };
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
            routers.scrutiny = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "scrutiny";
              entryPoints = [ "web" ];
              middlewares = [ "security-headers" ];
            };

            services.scrutiny.loadBalancer = {
              servers = [ { url = "http://localhost:${toString cfg.port}"; } ];
              passHostHeader = true;
            };
          };
        };

    assertions = [
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.scrutiny.reverseProxy.domain must be set when cfTunnel.enable is true";
      }
    ];
  };
}
