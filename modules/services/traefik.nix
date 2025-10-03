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

    certFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the TLS certificate file.
        If set, will be loaded securely via systemd LoadCredential.
      '';
    };

    keyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the TLS private key file.
        If set, will be loaded securely via systemd LoadCredential.
      '';
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

    # Securely load TLS certificates via systemd credentials
    systemd.services.traefik.serviceConfig = {
      LoadCredential = lib.optionals (cfg.certFile != null && cfg.keyFile != null) [
        "tls.crt:${cfg.certFile}"
        "tls.key:${cfg.keyFile}"
      ];
    };
  };
}
