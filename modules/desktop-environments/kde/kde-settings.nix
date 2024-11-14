{ config, lib, pkgs, ... }:

{
  services = {
    xserver = {
      enable = false; # Disables the X11 server; enables Wayland
    };

    displayManager = {
      #defaultSession = "plasma"; # Change to "plasmaX11" for X11

      sddm = {
        enable = true;
        wayland.enable = true;
        autoNumlock = true;
      };
    };

    desktopManager = {
      plasma6 = {
        enable = true;
      };
    };
  };

  #environment.plasma6.excludePackages = with pkgs.kdePackages; [ ];
}
