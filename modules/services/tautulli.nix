{ lib, config, ... }:
let
  cfg = config.telometto.services.tautulli or { };
in
{
  options.telometto.services.tautulli = {
    enable = lib.mkEnableOption "Tautulli";
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/tautulli";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.tautulli = {
      enable = lib.mkDefault true;
      inherit (cfg) dataDir;
      openFirewall = lib.mkDefault cfg.openFirewall;
    };
  };
}
