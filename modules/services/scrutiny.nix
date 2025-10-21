{ lib, config, ... }:
let
  cfg = config.telometto.services.scrutiny or { };
in
{
  options.telometto.services.scrutiny = {
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

    # Contribute to Traefik configuration if reverse proxy is enabled and Traefik is available
    telometto.services.traefik =
      lib.mkIf (cfg.reverseProxy.enable && config.telometto.services.traefik.enable or false)
        {
          # Services: path-based for Tailscale and optionally domain-based for Cloudflare
          services = {
            # Main path-based service (for Tailscale: blizzard.ts.net/scrutiny)
            scrutiny = {
              backendUrl = "http://localhost:${toString cfg.port}/";
              inherit (cfg.reverseProxy) pathPrefix stripPrefix extraMiddlewares;
              customHeaders = {
                X-Forwarded-Proto = "https";
                X-Forwarded-Host =
                  config.telometto.services.traefik.domain or "${config.networking.hostName}.local";
              };
            };
          }
          // lib.optionalAttrs (cfg.reverseProxy.domain != null) {
            # Additional domain-based service (for Cloudflare: scrutiny.example.com)
            "scrutiny-domain" = {
              backendUrl = "http://localhost:${toString cfg.port}/";
              pathPrefix = "/";
              stripPrefix = false;
              extraMiddlewares = cfg.reverseProxy.extraMiddlewares;
              customHeaders = {
                X-Forwarded-Proto = "https";
                X-Forwarded-Host = cfg.reverseProxy.domain;
              };
            };
          };

          # Override the router rule for the domain-based service
          dynamicConfigOptions = lib.mkIf (cfg.reverseProxy.domain != null) {
            http.routers."scrutiny-domain" = {
              rule = "Host(`${cfg.reverseProxy.domain}`)";
              service = "scrutiny-domain";
              entrypoints = [ "websecure" ];
              tls.certResolver = config.telometto.services.traefik.certResolver or "myresolver";
            };
          };
        };
  };
}
