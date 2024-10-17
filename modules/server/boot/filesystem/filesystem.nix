# Filesystem configuration defaults
{ config, lib, pkgs, ... }:

{
  # Bootloader
  boot = {
    supportedFilesystems = [ "zfs" ]; # "nfs" ];

    zfs = {
      forceImportRoot = false;
      extraPools = [ "tank" "flash_temp" ];
    };
  };

  services = {
    zfs = {
      autoScrub.enable = true;
      trim.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    zfs
    zfstools
    sanoid # ZFS snapshot management
  ];
}
