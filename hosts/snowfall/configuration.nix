# Simplified host configuration for Snowfall (Desktop)
{ config, lib, pkgs, VARS, inputs, mylib, ... }:

let
  deviceConfigs =
    import ../../devices/configurations.nix { inherit config lib pkgs VARS; };
in {
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

  # Apply device-specific configuration
  environment = deviceConfigs.snowfall.environment;
  hardware = deviceConfigs.snowfall.hardware;
  networking = deviceConfigs.snowfall.networking;
  services = deviceConfigs.snowfall.services;
  systemd = deviceConfigs.snowfall.systemd;
  fileSystems = deviceConfigs.snowfall.fileSystems;
  boot = lib.mkMerge [ deviceConfigs.snowfall.boot ];
  # programs/security/xdg not provided in device configs

  # Virtualization
  # Desktop profile + shared podman module set defaults

  system.stateVersion = "24.05";
}
