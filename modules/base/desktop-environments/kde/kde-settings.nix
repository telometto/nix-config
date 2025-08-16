{ config, lib, pkgs, ... }:

{
  environment.variables.SSH_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
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
        theme = "sddm-astronaut-theme";

        extraPackages = with pkgs; [
          kdePackages.qtsvg
          kdePackages.qtmultimedia
          kdePackages.qtvirtualkeyboard
        ];
      };
    };

    desktopManager = {
      plasma6 = {
        enable = true;
      };
    };
  };

  # programs.ssh = { askPassword = "${pkgs.kdePackages.ksshaskpass.out}/bin/ksshaskpass"; };

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

    (sddm-astronaut.override {
      embeddedTheme = "post-apocalyptic_hacker";
    })
  ];

  environment.plasma6.excludePackages = with pkgs.kdePackages; [ gwenview ];
}
