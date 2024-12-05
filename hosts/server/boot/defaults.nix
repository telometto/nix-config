# Filesystem configuration defaults
{ config, lib, pkgs, ... }:

{
  # Bootloader
  boot = {
    supportedFilesystems = [ "zfs" ];

    zfs = {
      forceImportRoot = false;
      forceImportAll = false;
      # extraPools = [ "tank" "flash_temp" ]; # Commented out for testing
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
      enable = false;

      lockdPort = 4001;
      mountdPort = 4002;
      statdPort = 4000;

      # extraNfsdConfig = '''';

      # Commented out for testing
      # exports = ''
      #   /flash_temp/nfsshare 192.168.2.100 (rw,async,no_subtree_check)
      # '';
    };
  };

  # NFS sharing
  fileSystems = {
    "/tank" = {
      device = "tank";
      mountPoint = "/tank";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/flash_temp" = {
      device = "flash_temp";
      mountPoint = "/flash_temp";
      fsType = "zfs";
      neededForBoot = true;
    };

    # Commented out for testing
    # "/flash_temp" = {
    #   device = "/flash_temp/nfsshare";
    #   # fsType = "zfs"; # Defaults to auto; "zfs" might not be valid
    #   options = [ "bind" ];
    # };
  };

  environment.systemPackages = with pkgs; [
    zfs
    zfstools
  ];
}
