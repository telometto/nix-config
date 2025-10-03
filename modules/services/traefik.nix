{ lib, config, ... }:
let
  cfg = config.telometto.services.traefik;
in
{
  options.telometto.services.traefik = {
    enable = lib.mkEnableOption "Traefik reverse proxy";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/traefik";
      description = "Directory where Traefik stores its data (e.g., acme.json for Let's Encrypt).";
    };

    staticConfigOptions = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Static configuration options for Traefik.
        These are passed to services.traefik.staticConfigOptions.
        See https://doc.traefik.io/traefik/reference/static-configuration/overview/
      '';
    };

    dynamicConfigOptions = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Dynamic configuration options for Traefik.
        These define routers, services, middlewares, and TLS configurations.
        See https://doc.traefik.io/traefik/reference/dynamic-configuration/overview/
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.traefik = {
      enable = true;

      inherit (cfg) dataDir staticConfigOptions dynamicConfigOptions;
    };
  };
}
