/**
 * This NixOS module configures Podman for container virtualization.
 * It enables Podman with Docker compatibility, sets up storage settings,
 * and includes necessary system packages for Podman functionality.
 *
 * - `virtualisation.containers.enable`: Enables container support.
 * - `virtualisation.containers.storage.settings.storage.driver`: Sets the storage driver for containers.
 * - `virtualisation.podman.enable`: Enables Podman.
 * - `virtualisation.podman.dockerCompat`: Enables Docker compatibility mode for Podman.
 * - `virtualisation.podman.dockerSocket.enable`: Enables the Docker socket for Podman.
 * - `virtualisation.podman.autoPrune.enable`: Enables automatic pruning of unused containers and images.
 * - `virtualisation.podman.defaultNetwork.settings.dns_enabled`: Enables DNS for the default network.
 * - `virtualisation.oci-containers.backend`: Sets the OCI container backend to Podman.
 * - `environment.systemPackages`: Installs necessary packages including Podman, Podman Compose, Podman TUI, and Shadow.
 */

{ config, lib, pkgs, VARS, ... }:
let
  # TODO: Change desktop root fs to btrfs
  STORAGEDRIVER =
    if config.networking.hostName == VARS.systems.desktop.hostName then
      "overlay" # When TODO has been implemented, change this to "btrfs"
    else
      "overlay"; # Fallback driver
in
{
  virtualisation = {
    containers = {
      enable = lib.mkIf config.virtualisation.podman.enable true;

      storage = {
        settings = {
          storage = {
            driver = STORAGEDRIVER;
          };
        };
      };
    };

    podman = {
      enable = true; # Enables podman
      dockerCompat = true; # Enables docker compatibility
      dockerSocket.enable = true; # Enables docker socket
      autoPrune.enable = true; # Enables auto pruning
      defaultNetwork.settings.dns_enabled = true; # Enables DNS
    };

    oci-containers = { backend = "podman"; };
  };

  environment.systemPackages = with pkgs; [
    podman
    podman-compose
    podman-tui
    shadow # Required by rootless podman on ZFS
  ];
}
