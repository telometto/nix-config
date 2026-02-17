{ lib, config, ... }:
let
  cfg = config.sys.services.scrutiny or { };
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
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

      settings.web.listen.port = cfg.port;

      collector = lib.mkIf (cfg.collectorSettings != { }) {
        settings = cfg.collectorSettings;
      };
    };

    services.traefik.dynamic.files.scrutiny = traefikLib.mkTraefikDynamicConfig {
      name = "scrutiny";
      inherit cfg config;
      inherit (cfg) port;
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion {
        name = "scrutiny";
        inherit cfg;
      })
    ];
  };
}
