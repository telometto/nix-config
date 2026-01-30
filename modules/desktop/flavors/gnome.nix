{
  lib,
  config,
  pkgs,
  ...
}:
let
  flavor = config.sys.desktop.flavor or "none";
  is = v: flavor == v;
in
{
  config = lib.mkIf (is "gnome") {
    programs = {
      gnome-disks.enable = lib.mkDefault true;
      gnome-terminal.enable = lib.mkDefault false;
      light.brightnessKeys.enable = lib.mkDefault true;
      seahorse.enable = lib.mkDefault true;
      ssh.startAgent = lib.mkForce false; # services.gnome.gcr-ssh-agent.enable cannot be enabled at the same time
    };

    services = {
      xserver = {
        enable = lib.mkDefault false;
        desktopManager.xterm.enable = lib.mkForce false;
      };
      desktopManager.gnome.enable = lib.mkDefault true;
      displayManager.gdm = {
        enable = lib.mkDefault true;
        autoSuspend = lib.mkDefault false;
      };

      gnome = {
        core-developer-tools.enable = lib.mkDefault true;
        core-os-services.enable = lib.mkDefault true;
        core-shell.enable = lib.mkDefault true;
        glib-networking.enable = lib.mkDefault true;
        gnome-keyring.enable = lib.mkDefault true;
        gnome-online-accounts.enable = lib.mkDefault true;
        gnome-settings-daemon.enable = lib.mkDefault true;
        sushi.enable = lib.mkDefault true;
      };

      hardware.bolt.enable = lib.mkDefault true;
    };

    # Prefer GNOME portal to avoid conflicts
    # xdg.portal = {
    #   enable = lib.mkDefault true;
    #   extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-gnome ];
    #   xdgOpenUsePortal = lib.mkDefault true;
    #   config.common.default = lib.mkDefault "*";
    # };

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

    environment.systemPackages = [ ];

    environment.gnome.excludePackages = [
      pkgs.gnome-tour
      pkgs.gnome-builder
      pkgs.gnome-maps
      pkgs.epiphany
      pkgs.geary
      pkgs.xterm
      pkgs.devhelp
    ];
  };
}
