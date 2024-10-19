# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  hardware.steam-hardware.enable = true;

  programs = {
    steam = {
      enable = true;
      extest.enable = true; # Translate X11 input events to Wayland
      protontricks.enable = true; # Run Proton games with custom settings

      extraPackages = with pkgs; [
        gamescope
        #protontricks
        steam
        #steam-run
        steamcontroller
        steamtinkerlaunch
      ];

      package = pkgs.steam.override { withJava = true; };
    };

    java.enable = true;
  };

  environment.systemPackages = with pkgs; [ steam ];
}
