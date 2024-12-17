/**
 * This Nix module configures Docker for different host systems. It sets up
 * host-specific system configuration defaults for Docker, including storage
 * driver and root path based on the hostname of the machine. It also enables
 * rootless Docker with specific daemon settings and includes Docker-related
 * packages in the system environment.
 *
 * - `STORAGEDRIVER`: Determines the Docker storage driver based on the hostname.
 * - `ROOTPATH`: Sets the Docker data root path based on the hostname.
 * - `virtualisation.docker`: Configures Docker settings, including enabling rootless mode and setting daemon options.
 * - `virtualisation.oci-containers`: Configures OCI containers to use Docker as the backend if Docker is enabled and Podman is not.
 * - `environment.systemPackages`: Installs Docker-related packages.
 */

{ config, lib, pkgs, VARS, ... }:
let
  isPodmanEnabled = !config.virtualisation.podman.enable;

  DRIVE_BASE_PATH = "/run/media/${VARS.users.admin.user}";

  # TODO: Change desktop root fs to btrfs
  STORAGEDRIVER =
    if config.networking.hostName == VARS.systems.desktop.hostName then
      "overlay2" # See TODO; when this has been implemented, change this to "btrfs"
    # else if config.networking.hostName == VARS.systems.server.hostname then
    #   "zfs"
    else
      "overlay2"; # Fallback driver

  ROOTPATH =
    if config.networking.hostName == VARS.systems.desktop.hostName then
      "${DRIVE_BASE_PATH}/personal/.containers"
    # else if config.networking.hostName == VARS.systems.server.hostname then
    #   "/tank/containers"
    else
      "${config.home.homeDirectory}/.containers"; # Fallback path
in
lib.mkIf isPodmanEnabled
{
  virtualisation = {
    docker = {
      enable = true;

      rootless = {
        enable = true;
        setSocketVariable = true;
      };

      daemon.settings = {
        data-root = ROOTPATH;
        userland-proxy = false;
        experimental = true;
        metrics-addr = "0.0.0.0:9323";
        ipv6 = true;
        #fixed-cidr-v6 = "fd00::/80";
      };

      storageDriver = STORAGEDRIVER;
    };

    oci-containers = {
      backend = "docker";
    };
  };

  environment.systemPackages = with pkgs; [
    docker
    docker-client
    docker-compose
    docker-compose-language-service
    docker-gc
  ];
}
