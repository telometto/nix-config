{ config, lib, pkgs, ... }:

{
  programs = {
    gnome-disks.enable = true;
    gnome-terminal.enable = false;
    light.brightnessKeys.enable = true; # Keyboard backlight
    seahorse.enable = true;
  };

  services = {
    hardware.bolt.enable = true;

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

    xserver = {
      enable = true; # Enable the X11 windowing system

      desktopManager = {
        gnome = {
          enable = true;
        };
      };

      # Enable the GNOME Desktop Environment
      displayManager = {
        gdm = {
          enable = true;
          autoSuspend = false;
        };
      };
    };
  };
}
