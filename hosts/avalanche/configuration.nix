# Simplified host configuration for Avalanche (Laptop)
{ config, lib, pkgs, VARS, inputs, mylib, ... }:

let
  deviceConfigs =
    import ../../devices/configurations.nix { inherit config lib pkgs VARS; };
in
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

    # User definitions
    ../../users
  ];

  # Apply device-specific configuration
  environment = deviceConfigs.avalanche.environment;
  hardware = deviceConfigs.avalanche.hardware;
  networking = deviceConfigs.avalanche.networking;
  services = deviceConfigs.avalanche.services;
  systemd = deviceConfigs.avalanche.systemd;
  boot = lib.mkMerge [ deviceConfigs.avalanche.boot ];
  security = deviceConfigs.avalanche.security;
  programs = deviceConfigs.avalanche.programs;
  virtualisation = deviceConfigs.avalanche.virtualisation;
  # XDG portal from shared/desktop-common.nix

  system.stateVersion = "24.05";
}
