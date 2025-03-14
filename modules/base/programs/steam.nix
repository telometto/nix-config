# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:

{
  #hardware.steam-hardware.enable = true;

  programs = {
    gamescope = {
      enable = true;
      capSysNice = true;
    };

    steam = {
      enable = true;
      extest.enable = true; # Translate X11 input events to Wayland
      protontricks.enable = true; # Run Proton games with custom settings

      gamescopeSession = {
        enable = true; # Enable GameScope session
      };

      extraPackages = with pkgs; [
        gamescope
        #protontricks
        #steam
        #steam-run
        steamcontroller
        steamtinkerlaunch
      ];

      #package = pkgs.steam.override { withJava = true; }; # Deprecated since 23.05
    };

    java = {
      enable = true;
      package = pkgs.jdk23;
    };

    gamemode.enable = true;
  };

  environment.systemPackages = with pkgs; [ steam ];
}
