{
  lib,
  config,
  pkgs,
  ...
}:
let
  flavor = config.sys.desktop.flavor or "none";
  is = v: flavor == v;
  SDDM_THEME = "hyprland_kath"
in
{
  config = lib.mkIf (is "kde") {
    services = {
      xserver.enable = lib.mkDefault false;
      desktopManager.plasma6.enable = lib.mkDefault true;

      displayManager.sddm = {
        enable = lib.mkDefault true;

        wayland.enable = lib.mkDefault true;
        autoNumlock = lib.mkDefault true;
        /**
          Available themes:
          astronaut
          black_hole
          cyberpunk
          hyprland_kath
          jake_the_dog
          japanese_aesthetic
          pixel_sakura
          post-apocalyptic_hacker
          purple_leaves
        */
        theme = "sddm-astronaut-theme";
        extraPackages = [
          pkgs.kdePackages.qtsvg
          pkgs.kdePackages.qtmultimedia
          pkgs.kdePackages.qtvirtualkeyboard
        ];
      };
    };

    environment = {
      variables.SSH_ASKPASS_REQUIRE = lib.mkDefault "prefer";

      systemPackages = [
        pkgs.kdePackages.ksshaskpass
        pkgs.kdePackages.kwallet
        pkgs.kdePackages.kwalletmanager
        # pkgs.kdePackages.kwallet-pam
        pkgs.kdePackages.qtwayland
        pkgs.kdePackages.qtwebengine
        pkgs.xwayland
        (pkgs.sddm-astronaut.override {
          embeddedTheme = SDDM_THEME;
        })
      ];

      plasma6.excludePackages = with pkgs.kdePackages; [ gwenview ];
    };

    programs = {
      kdeconnect.enable = lib.mkDefault true;

      xwayland.enable = lib.mkDefault true;

      # Configure SSH agent to work with KDE/KWallet
      ssh = {
        startAgent = lib.mkDefault true;
        enableAskPassword = lib.mkDefault true;
        askPassword = lib.mkDefault "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
      };
    };

    # Prefer KDE portal
    # xdg.portal = {
    #   enable = lib.mkDefault true;
    #   extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-kde ];
    #   xdgOpenUsePortal = lib.mkDefault true;
    #   config.common.default = lib.mkDefault "*";
    # };

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
  };
}
