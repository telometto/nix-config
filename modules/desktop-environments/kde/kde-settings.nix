{ config, lib, pkgs, ... }:

{
  services = {
    xserver = {
      enable = false; # Enables or disables the X11 server
    };

    displayManager = {
      # defaultSession = "plasma"; # Change to "plasmaX11" for X11

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

  security.pam.services = {
    sddm = {
      enableAppArmor = true;
      gnupg.enable = true;
      kwallet.enable = true;
    };

    kwallet = {
      enableAppArmor = true;
      gnupg.enable = true;
      kwallet.enable = true;
    };
  };

  #environment.plasma6.excludePackages = with pkgs.kdePackages; [ ];
}
