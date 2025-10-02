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

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/tautulli/config.ini";
      description = "This should be set so that config isn't reset every time the app (re)starts.";
    }

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.tautulli = {
      enable = lib.mkDefault true;
      inherit (cfg) dataDir configFile;
      openFirewall = lib.mkDefault cfg.openFirewall;
    };
  };
}
