{ lib, config, ... }:
let
  cfg = config.telometto.services.plex or { };
in
{
  options.telometto.services.plex.enable = lib.mkEnableOption "Plex Media Server";
  options.telometto.services.plex.openFirewall = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    services.plex = {
      enable = lib.mkDefault true;
      openFirewall = lib.mkDefault cfg.openFirewall;
    };
  };
}
