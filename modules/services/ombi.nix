{ lib, config, ... }:
let
  cfg = config.telometto.services.ombi or { };
in
{
  options.telometto.services.ombi = {
    enable = lib.mkEnableOption "Ombi";
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

      port = lib.mkOption {
        type = lib.types.port;
        default = 5000;
        description = "Port where Ombi listens.";
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
    };
  };

  config = lib.mkIf cfg.enable {
    services.ombi = {
      enable = true;
      inherit (cfg) dataDir openFirewall;
    };

    # Contribute to Traefik configuration if reverse proxy is enabled and Traefik is available
    # COMMENTED OUT - Using standard NixOS Traefik module instead
    # telometto.services.traefik =
    #   lib.mkIf (cfg.reverseProxy.enable && config.telometto.services.traefik.enable or false)
    #     {
    #       # Services: path-based for Tailscale and optionally domain-based for Cloudflare
    #       services = {
    #         # Main path-based service (for Tailscale: blizzard.ts.net/ombi)
    #         ombi = {
    #           backendUrl = "http://localhost:${toString cfg.reverseProxy.port}/";
    #           inherit (cfg.reverseProxy) pathPrefix stripPrefix extraMiddlewares;
    #           customHeaders = {
    #             X-Forwarded-Proto = "https";
    #             X-Forwarded-Host =
    #               config.telometto.services.traefik.domain or "${config.networking.hostName}.local";
    #           };
    #         };
    #       };
    #
    #       # Manual configuration for domain-based routing (bypasses auto-generation)
    #       dynamicConfigOptions = lib.mkIf (cfg.reverseProxy.domain != null) {
    #         http = {
    #           # Middleware for domain-based service
    #           middlewares."ombi-domain-headers" = {
    #             headers.customRequestHeaders = {
    #               X-Forwarded-Proto = "https";
    #               X-Forwarded-Host = cfg.reverseProxy.domain;
    #             };
    #           };
    #
    #           # Router for domain-based service with correct Host rule
    #           routers."ombi-domain" = {
    #             rule = "Host(`${cfg.reverseProxy.domain}`)";
    #             service = "ombi-domain";
    #             middlewares = [ "ombi-domain-headers" ] ++ cfg.reverseProxy.extraMiddlewares;
    #             entrypoints = [ "websecure" ];
    #             tls.certResolver = config.telometto.services.traefik.certResolver or "myresolver";
    #           };
    #
    #           # Service definition for domain-based routing
    #           services."ombi-domain".loadBalancer = {
    #             servers = [ { url = "http://localhost:${toString cfg.reverseProxy.port}/"; } ];
    #             passHostHeader = true;
    #           };
    #         };
    #       };
    #     };
  };
}
