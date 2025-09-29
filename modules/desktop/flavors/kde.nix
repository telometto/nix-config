{
  lib,
  config,
  pkgs,
  ...
}:
# Single-owner KDE (Plasma 6) flavor module replicated under rewrite/, gated by telometto.desktop.flavor
let
  flavor = config.telometto.desktop.flavor or "none";
  is = v: flavor == v;
in
{
  config = lib.mkIf (is "kde") {
    # Plasma + SDDM
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = lib.mkDefault true;
      autoNumlock = lib.mkDefault true;
      theme = lib.mkForce "sddm-astronaut-theme";
      extraPackages = with pkgs; [
        kdePackages.qtsvg
        kdePackages.qtmultimedia
        kdePackages.qtvirtualkeyboard
      ];
    };

    # Askpass and Wayland bits carried from legacy
    environment = {
      variables.SSH_ASKPASS = lib.mkForce "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

      # Useful KDE packages
      systemPackages = [
        pkgs.kdePackages.kwallet
        pkgs.kdePackages.kwalletmanager
        pkgs.kdePackages.kwallet-pam
        pkgs.kdePackages.ksshaskpass
        pkgs.kdePackages.qtwayland
        pkgs.xwayland
        pkgs.kdePackages.xwaylandvideobridge
        (pkgs.sddm-astronaut.override {
          embeddedTheme = "post-apocalyptic_hacker";
        })
      ];

      plasma6.excludePackages = with pkgs.kdePackages; [ gwenview ];
    };

    programs.xwayland.enable = lib.mkDefault true;

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
