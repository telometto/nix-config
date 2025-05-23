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
        theme = "sddm-astronaut";
        # "${{pkgs.fetchFromGitHub {
        #   owner = "";
        #   repo = "";
        #   rev = "";
        #   sha256 = "";
        # }}}"
      };
    };

    desktopManager = {
      plasma6 = {
        enable = true;
      };
    };
  };

  security.pam.services = {
    login = {
      enableAppArmor = true;
      gnupg.enable = true;
      kwallet.enable = true;
    };

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

  environment.systemPackages = with pkgs; [
    # Your KDE packages here
    kdePackages.kwallet
    kdePackages.kwalletmanager
    kdePackages.kwallet-pam
    kdePackages.ksshaskpass

    sddm-astronaut
  ];

  environment.plasma6.excludePackages = with pkgs.kdePackages; [ gwenview ];
}
