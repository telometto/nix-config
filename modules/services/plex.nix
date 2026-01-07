{ lib, config, ... }:
let
  cfg = config.sys.services.plex or { };
in
{
  options.sys.services.plex.enable = lib.mkEnableOption "Plex Media Server";

  options.sys.services.plex.openFirewall = lib.mkOption {
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
