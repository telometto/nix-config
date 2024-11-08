# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  virtualisation = {
    containers = {
      enable = true;
    };

    podman = {
      enable = true; # Enables podman
      dockerCompat = true; # Enables docker compatibility
      dockerSocket.enable = true; # Enables docker socket
      autoPrune.enable = true; # Enables auto pruning
      defaultNetwork.settings.dns_enabled = true; # Enables DNS
    };

    oci-containers = { # lib.mkIf (!config.virtualisation.docker.enable && config.virtualisation.podman.enable) {
      backend = "podman"; # Sets the backend to podman
    };
  };

  environment.systemPackages = with pkgs; [
    podman
    podman-compose
    podman-tui
    shadow # Required by rootless podman on ZFS
  ];
}
