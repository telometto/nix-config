{ config, lib, pkgs, ... }:

{
  environment.variables.SSH_ASKPASS =
    "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

  services = {
    xserver = {
      enable = false; # Disable X11, using Wayland
    };

    displayManager = {
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

    desktopManager = { plasma6 = { enable = true; }; };
  };

  programs = { xwayland = { enable = true; }; };

  # KDE-specific PAM (kwallet + hardening) here, not globally
  security.pam.services = {
    login = { enableAppArmor = true; gnupg.enable = true; kwallet.enable = true; };
    sddm = { enableAppArmor = true; gnupg.enable = true; kwallet.enable = true; };
  };

  environment.systemPackages = with pkgs; [
    # KDE packages
    kdePackages.kwallet
    kdePackages.kwalletmanager
    kdePackages.kwallet-pam
    kdePackages.ksshaskpass
    kdePackages.qtwayland
    xwayland
    kdePackages.xwaylandvideobridge

    (sddm-astronaut.override { embeddedTheme = "post-apocalyptic_hacker"; })
  ];

  environment.plasma6.excludePackages = with pkgs.kdePackages; [ gwenview ];
}
