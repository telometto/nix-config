{ lib, config, pkgs, ... }:
# Single-owner GNOME flavor module replicated under rewrite/, gated by telometto.desktop.flavor
let
  flavor = (config.telometto.desktop.flavor or "none");
  is = v: flavor == v;
in {
  config = lib.mkIf (is "gnome") {
    programs = {
      gnome-disks.enable = true;
      gnome-terminal.enable = false;
      light.brightnessKeys.enable = true;
      seahorse.enable = true;
    };

    services = {
      # GNOME needs the display stack; enable X server integration (Wayland still works via GDM)
      xserver.enable = lib.mkDefault true;
      desktopManager.gnome.enable = true;
      displayManager.gdm = {
        enable = true;
        autoSuspend = lib.mkDefault false;
      };

      gnome = {
        core-developer-tools.enable = true;
        core-os-services.enable = true;
        core-shell.enable = true;
        glib-networking.enable = true;
        gnome-keyring.enable = true;
        gnome-online-accounts.enable = true;
        gnome-settings-daemon.enable = true;
        sushi.enable = true;
      };

      hardware.bolt.enable = true;
    };

    # Prefer GNOME portal to avoid conflicts
    # xdg.portal = {
    #   enable = lib.mkDefault true;
    #   extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-gnome ];
    #   xdgOpenUsePortal = lib.mkDefault true;
    #   config.common.default = lib.mkDefault "*";
    # };

    # PAM hardening + keyring integration similar to legacy
    security.pam.services = {
      gdm = {
        enableAppArmor = true;
        gnupg.enable = true;
        enableGnomeKeyring = true;
      };
      login = {
        enableAppArmor = true;
        gnupg.enable = true;
        enableGnomeKeyring = true;
      };
    };

    environment.systemPackages = [
      # pkgs.gnome.gnome-tweaks
      # pkgs.gnomeExtensions.appindicator
    ];

    # Trim default GNOME apps as in legacy
    environment.gnome.excludePackages = [
      pkgs.gnome-tour
      pkgs.gnome-builder
      pkgs.gnome-maps
      pkgs.epiphany
      pkgs.geary
    ];
  };
}
