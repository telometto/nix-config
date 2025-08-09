# Simplified host configuration for Blizzard (Server)
{ config, lib, pkgs, VARS, inputs, mylib, ... }:

let
  deviceConfigs =
    import ../../devices/configurations.nix { inherit config lib pkgs VARS; };
in {
  imports = [
    # Hardware scan (don't touch)
    ./hardware-configuration.nix

    # Shared system configuration
    ../../shared/system.nix
    ../../shared/profiles/server.nix
    ../../shared/virtualisation/podman.nix

    # MicroVM host support (server runs microvms)
    inputs.microvm.nixosModules.host

    # User definitions
    ../../users
  ];

  # Apply device-specific configuration
  inherit (deviceConfigs.blizzard)
    networking systemd fileSystems services environment;

  system.stateVersion = "24.11";
}
