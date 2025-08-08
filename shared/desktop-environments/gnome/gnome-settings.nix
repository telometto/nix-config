{ config, lib, pkgs, ... }:

{
  # Prefer Wayland; GNOME brings XWayland automatically, but keep explicit for clarity
  services = {
    xserver = {
      enable = false; # Wayland-first
    };

    displayManager.gdm = {
      enable = true;
      wayland = true;
    };

    desktopManager.gnome.enable = true;
  };

  programs.xwayland.enable = true;

  # Add a couple of helpful GNOME system packages; keep most apps in Home Manager
  environment.systemPackages = with pkgs; [
    gnome.gnome-control-center
    gnome.gnome-settings-daemon
  ];

  # GNOME-specific PAM hardening and keyring integration
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
}
