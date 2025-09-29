{ lib, config, ... }:
let
  cfg = config.telometto.services.scrutiny or { };
in
{
  options.telometto.services.scrutiny.enable = lib.mkEnableOption "Scrutiny SMART monitoring";
  options.telometto.services.scrutiny.port = lib.mkOption {
    type = lib.types.port;
    default = 8072;
  };
  config = lib.mkIf cfg.enable {
    services.scrutiny = {
      enable = lib.mkDefault true;
      openFirewall = lib.mkDefault true;
      settings.web.listen.port = cfg.port;
    };
  };
}
