# Filesystem configuration defaults
{ config, lib, pkgs, ... }:

{
  # Bootloader
  boot = {
    supportedFilesystems = [ "nfs" ]; # Upon changing to btrfs; add here
  };

  services = {
    fstrim = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    libnfs
    nfs-utils
  ];
}
