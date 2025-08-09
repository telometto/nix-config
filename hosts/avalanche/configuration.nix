# Simplified host configuration for Avalanche (Laptop)
{ config, lib, pkgs, VARS, inputs, mylib, ... }:

{
  imports = [
    # Hardware scan (don't touch)
    ./hardware-configuration.nix

    # Shared system configuration and profiles
    ../../shared/system.nix
    ../../shared/profiles/laptop.nix
    ../../shared/virtualisation/podman.nix

    # Desktop common services (Flatpak, portals, etc.)
    ../../shared/desktop-common.nix

    # GNOME desktop
    ../../shared/desktop-environments/gnome/gnome-settings.nix

    # Device specific configuration
    ../../devices/avalanche.nix

    # User definitions
    ../../users
  ];

  system.stateVersion = "24.05";
}
