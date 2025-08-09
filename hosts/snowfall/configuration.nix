# Simplified host configuration for Snowfall (Desktop)
{ config, lib, pkgs, VARS, inputs, mylib, ... }:

{
  imports = [
    # Hardware scan (don't touch)
    ./hardware-configuration.nix

    # Shared system configuration and profiles
    ../../shared/system.nix
    ../../shared/profiles/desktop.nix
    ../../shared/virtualisation/podman.nix

    # Desktop common services (Flatpak, portals, etc.)
    ../../shared/desktop-common.nix

    # KDE desktop
    ../../shared/desktop-environments/kde/kde-settings.nix

    # MicroVM host support (optional for desktop; comment out if not needed)
    # inputs.microvm.nixosModules.host

    # User definitions
    ../../users
  ];

  system.stateVersion = "24.05";
}
