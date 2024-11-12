# Filesystem configuration defaults
{ config, lib, pkgs, ... }:

{
  # Bootloader
  boot = {
    supportedFilesystems = [ "zfs" ];

    zfs = {
      forceImportRoot = false;
      extraPools = [ "tank" "flash_temp" ];
    };
  };

  services = {
    zfs = {
      autoScrub.enable = true;

      autoSnapshot = {
        enable = true;

        monthly = 4;
        weekly = 7;
        daily = 2;

        flags = "-u";
      };

      trim.enable = true;
    };

    nfs.server = {
      enable = true;
      exports = ''
        /flash_temp/nfsshare 192.168.2.100 (rw,async,no_subtree_check)
      '';
    };
  };

  #  NFS sharing
  fileSystems = {
    "/flash_temp" = {
      device = "/flash_temp/nfsshare";
      #fsType = "zfs"; # Defaults to auto
      options = [ "defaults" ];
    };
  };

  environment.systemPackages = with pkgs; [
    zfs
    zfstools
  ];
}
