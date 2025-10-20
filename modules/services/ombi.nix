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
    telometto.services.traefik.services = lib.mkIf (
      cfg.reverseProxy.enable && config.telometto.services.traefik.enable or false
    ) {
      ombi = {
        backendUrl = "http://localhost:${toString cfg.reverseProxy.port}/";

        inherit (cfg.reverseProxy) pathPrefix stripPrefix extraMiddlewares;

        customHeaders = {
          X-Forwarded-Proto = "https";
          X-Forwarded-Host = config.telometto.services.traefik.domain or "${config.networking.hostName}.local";
        };
      };
    };
  };
}
