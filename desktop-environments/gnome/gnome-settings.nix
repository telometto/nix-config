{ config, lib, pkgs, ... }:

{
  programs = {
    gnome-disks.enable = true;
    gnome-terminal.enable = false;
    light.brightnessKeys.enable = true; # Keyboard backlight
    seahorse.enable = true;
  };

  services = {
    gnome = {
      core-developer-tools.enable = true;
      core-os-services.enable = true;
      core-shell.enable = true;
      glib-networking.enable = true;
      gnome-keyring.enable = true;
      gnome-online-accounts.enable = true;
      gnome-settings-daemon.enable = true;
      sushi.enable = true;
      hardware.bolt.enable = true;

      xserver = {
        desktopManager = {
          gnome = {
            enable = true;
            gdm = {
              enable = true;
              autoSuspend = false;
            };
          };
        };
      };
    };
  };
}
