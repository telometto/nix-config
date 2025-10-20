{ lib, config, ... }:
let
  cfg = config.telometto.services.tautulli;
in
{
  options.telometto.services.tautulli = {
    enable = lib.mkEnableOption "Tautulli";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/tautulli";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/tautulli/config.ini";
      description = "This should be set so that config isn't reset every time the app (re)starts.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Traefik reverse proxy configuration for Tautulli.";
      };

      pathPrefix = lib.mkOption {
        type = lib.types.str;
        default = "/tautulli";
        description = "URL path prefix for Tautulli.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8181;
        description = "Port where Tautulli listens.";
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to strip the path prefix before forwarding to Tautulli.";
      };

      extraMiddlewares = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional Traefik middlewares to apply.";
        example = [ "rate-limit" "security-headers" ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.tautulli = {
      enable = lib.mkDefault true;
      inherit (cfg) dataDir configFile openFirewall;
    };

    # Contribute to Traefik configuration if reverse proxy is enabled and Traefik is available
    telometto.services.traefik.services = lib.mkIf (
      cfg.reverseProxy.enable && config.telometto.services.traefik.enable or false
    ) {
      tautulli = {
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
