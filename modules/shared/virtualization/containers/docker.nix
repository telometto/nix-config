# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  virtualisation = {
    docker = {
      enable = false;

      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };

    oci-containers = { # lib.mkIf (config.virtualisation.docker.enable && !config.virtualisation.podman.enable) {
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
