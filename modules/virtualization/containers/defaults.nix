{ config, lib, pkgs, VARS, ... }:
let
  IS_DESKTOP = config.networking.hostName == VARS.systems.desktop.hostname;
  IS_PODMAN_ENABLED = config.virtualisation.podman.enable; # Set this true/false as needed

  # Base path for containers when using Docker rootless mode
  DRIVE_BASE_PATH = "/run/media/${VARS.users.admin.user}";

  # TODO: Change desktop root fs to btrfs when ready
  # Choose storage drivers based on whether Podman or Docker is used.
  STORAGEDRIVER =
    if IS_DESKTOP then
      if IS_PODMAN_ENABLED then "overlay" else "overlay2"
    else
      if IS_PODMAN_ENABLED then "overlay" else "overlay2";

  ROOTPATH =
    if IS_DESKTOP then
      "${DRIVE_BASE_PATH}/personal/.containers"
    else
      "${config.home.homeDirectory}/.containers";

  OCI_BACKEND = if IS_PODMAN_ENABLED then "podman" else "docker";
in
{
  virtualisation = {
    # Podman configuration
    podman = lib.mkIf IS_PODMAN_ENABLED {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      autoPrune.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    containers = lib.mkIf IS_PODMAN_ENABLED {
      enable = true;
      storage.settings.storage.driver = STORAGEDRIVER;
    };

    # Docker configuration
    docker = lib.mkIf (not IS_PODMAN_ENABLED) {
      enable = true;
      rootless.enable = true;
      rootless.setSocketVariable = true;
      daemon.settings = {
        data-root = ROOTPATH;
        userland-proxy = false;
        experimental = true;
        metrics-addr = "0.0.0.0:9323";
        ipv6 = true;
        # If needed, set fixed-cidr-v6 = "fd00::/80";
      };
      storageDriver = STORAGEDRIVER;
    };

    oci-containers.backend = OCI_BACKEND;
  };

  environment.systemPackages = with pkgs; (if IS_PODMAN_ENABLED then [
    podman
    podman-compose
    podman-tui
    shadow # Required for rootless podman on ZFS
  ] else [
    docker
    docker-client
    docker-compose
    docker-compose-language-service
    docker-gc
  ]);
}
