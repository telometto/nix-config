# Simplified host configuration for Blizzard (Server)
{ config, lib, pkgs, VARS, inputs, mylib, ... }:

let
  constants = import ../../shared/constants.nix;
  adminUser = VARS.users.admin.user;
  backups = constants.backups;
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

    # Device configuration
    ../../devices/blizzard.nix

    # User definitions
    ../../users
  ];

  # Migrate Borg job to my.backups
  my.backups.jobs.homeserver = {
    paths = "/home/${adminUser}";
    repo = backups.blizzardRepo;
    identityFile = "/home/${adminUser}/.ssh/borg-blizzard";
    encryption.passCommand = "cat ${backups.blizzardKeyFile}";
    startAt = "daily";
  };

  system.stateVersion = "24.11";
}
