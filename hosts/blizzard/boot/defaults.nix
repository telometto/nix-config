# Filesystem configuration defaults
{ config, lib, pkgs, ... }:

{
  # Bootloader
  boot = {
    supportedFilesystems = [ "zfs" ];

    initrd = {
      enable = true;

      # secrets = {
      #   "/hex.key" = /opt/sec/hex.key;
      # };
    };

    zfs = {
      forceImportRoot = false;
      # forceImportAll = false;
      extraPools = [
        "flash_temp" # SSD
        # "rpool" # HDD
      ];
    };
  };

  services = {
    zfs = {
      autoScrub.enable = true;

      autoSnapshot = {
        enable = false;

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
    ### TESTING
    "/rpool/enc/transfers" = {
      device = "rpool";
      fsType = "zfs";
    };

    "/rpool/unenc/apps" = {
      device = "rpool";
      fsType = "zfs";
    };

    "/rpool/unenc/dbs" = {
      device = "rpool";
      fsType = "zfs";
    };

    "/rpool/unenc/media" = {
      device = "rpool";
      fsType = "zfs";
    };

    "/rpool/unenc/vms" = {
      device = "rpool";
      fsType = "zfs";
    };

    #### END TESTING

  #   "/tank" = {
  #     device = "tank";
  #     mountPoint = "/tank";
  #     fsType = "zfs";
  #     neededForBoot = false;
  #   };

  #   "/flash_temp" = {
  #     device = "flash_temp";
  #     mountPoint = "/flash_temp";
  #     fsType = "zfs";
  #     neededForBoot = false;
  #   };

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
