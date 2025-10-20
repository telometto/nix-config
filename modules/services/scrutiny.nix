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
    telometto.services.traefik.services = lib.mkIf (
      cfg.reverseProxy.enable && config.telometto.services.traefik.enable or false
    ) {
      scrutiny = {
        backendUrl = "http://localhost:${toString cfg.port}/";

        inherit (cfg.reverseProxy) pathPrefix stripPrefix extraMiddlewares;

        customHeaders = {
          X-Forwarded-Proto = "https";
          X-Forwarded-Host = config.telometto.services.traefik.domain or "${config.networking.hostName}.local";
        };
      };
    };
  };
}
