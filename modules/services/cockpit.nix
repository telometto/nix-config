{ lib, config, ... }:
let
  cfg = config.telometto.services.cockpit or { };
in
{
  options.telometto.services.cockpit = {
    enable = lib.mkEnableOption "Cockpit web UI";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Cockpit.";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/cockpit";
        description = "URL path prefix for Cockpit.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to strip the path prefix before forwarding to Cockpit.";
      };

      extraMiddlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional Traefik middlewares to apply.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.cockpit = {
      enable = true;
      inherit (cfg) port openFirewall;
      settings.WebService.AllowUnencrypted = true;
    };

    # Contribute to Traefik configuration if reverse proxy is enabled and Traefik is available
    # COMMENTED OUT - Using standard NixOS Traefik module instead
    # telometto.services.traefik.services =
    #   lib.mkIf (cfg.reverseProxy.enable && config.telometto.services.traefik.enable or false)
    #     {
    #       cockpit = {
    #         backendUrl = "http://localhost:${toString cfg.port}/";
    #
    #         inherit (cfg.reverseProxy) pathPrefix stripPrefix extraMiddlewares;
    #
    #         customHeaders = {
    #           X-Forwarded-Proto = "https";
    #           X-Forwarded-Host =
    #             config.telometto.services.traefik.domain or "${config.networking.hostName}.local";
    #         };
    #       };
    #     };
  };
}
