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
  };

  config = lib.mkIf cfg.enable {
    services.scrutiny = {
      enable = lib.mkDefault true;
      openFirewall = lib.mkDefault false;
      settings.web.listen.port = cfg.port;

      collector = lib.mkIf (cfg.collectorSettings != { }) {
        settings = cfg.collectorSettings;
      };
    };
  };
}
