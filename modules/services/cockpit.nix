{ lib, config, ... }:
let
  cfg = config.sys.services.cockpit or { };
in
{
  options.sys.services.cockpit = {
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
  };
}
