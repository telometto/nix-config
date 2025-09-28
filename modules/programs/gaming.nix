{ lib, config, pkgs, ... }:
let cfg = config.telometto.programs.gaming;
in {
  options.telometto.programs.gaming.enable =
    lib.mkEnableOption "Gaming stack (gamescope, steam, gamemode)";
  config = lib.mkIf cfg.enable {
    hardware.steam-hardware.enable = lib.mkDefault true;

    programs = {
      gamescope = {
        enable = lib.mkDefault true;
        capSysNice = lib.mkDefault true;
      };
      steam = {
        enable = lib.mkDefault true;
        extest.enable = lib.mkDefault true;
        protontricks.enable = lib.mkDefault true;
        gamescopeSession.enable = lib.mkDefault true;
        extraPackages = with pkgs; [
          steam-run
          sc-controller  # Replaced deprecated steamcontroller
          steamtinkerlaunch
        ];
      };
      gamemode.enable = lib.mkDefault true;
    };
  };
}
