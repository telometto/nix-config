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
