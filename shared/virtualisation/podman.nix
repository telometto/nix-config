# Podman-only, for all devices; Docker disabled
{ config, lib, pkgs, VARS, mylib, ... }:
{
  virtualisation = {
    containers.enable = lib.mkDefault true;

    podman = {
      enable = lib.mkDefault true;
      dockerCompat = lib.mkDefault true;
      dockerSocket.enable = lib.mkDefault true;
      autoPrune.enable = lib.mkDefault true;
      defaultNetwork.settings.dns_enabled = lib.mkDefault true;
    };

    docker.enable = lib.mkForce false;
    oci-containers.backend = lib.mkDefault "podman";
  };
}
