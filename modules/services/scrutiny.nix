{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.scrutiny or { };
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
  tokenCredential = "scrutiny-token";
  scrutinyWithToken = pkgs.writeShellScript "scrutiny-with-token" ''
    set -euo pipefail

    export SCRUTINY_WEB_INFLUXDB_TOKEN="$(<"$CREDENTIALS_DIRECTORY/${tokenCredential}")"
    exec ${lib.getExe config.services.scrutiny.package} start --config /run/scrutiny/config.yaml
  '';
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

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "scrutiny"; };
  };

  config = lib.mkIf cfg.enable {
    services.scrutiny = {
      enable = lib.mkDefault true;

      inherit (cfg) openFirewall;

      settings.web = {
        listen.port = cfg.port;
        influxdb.host = "127.0.0.1";
      };

      # The upstream default derives the collector destination from the web
      # listen address.  A wildcard bind address is valid for listening but
      # is not a usable destination for a local client on Linux.
      collector.settings = lib.mkMerge [
        (lib.mkIf (cfg.collectorSettings != { }) cfg.collectorSettings)
        {
          api.endpoint = lib.mkDefault "http://127.0.0.1:${toString cfg.port}";
        }
      ];
    };

    systemd.services.scrutiny = {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
      serviceConfig = {
        ExecStart = lib.mkForce scrutinyWithToken;
        LoadCredential = "${tokenCredential}:${config.sys.secrets.scrutinyTokenFile}";
      };
    };

    services.traefik.dynamic.files.scrutiny = traefikLib.mkTraefikDynamicConfig {
      name = "scrutiny";
      inherit cfg config;
      inherit (cfg) port;
    };

    assertions = [
      {
        assertion = config.sys.secrets.scrutinyTokenFile != null;
        message = "sys.services.scrutiny requires sys.secrets.scrutinyTokenFile.";
      }
      (traefikLib.mkCfTunnelAssertion {
        name = "scrutiny";
        inherit cfg;
      })
    ];
  };
}
