# Filesystem configuration defaults
{ config, lib, pkgs, ... }:

{
  # Bootloader
  boot = {
    supportedFilesystems = [ "zfs" ];

    initrd = {
      enable = true;

      supportedFilesystems = { zfs = true; };
    };

    kernel = {
      sysctl = { "net.ipv4.conf.all.src_valid_mark" = 1; };
    };

    zfs = {
      # forceImportRoot = false;
      forceImportAll = true;
      requestEncryptionCredentials = true;
      devNodes = "/dev/disk/by-id";

      # extraPools = [
      #   "flash_temp" # SSD
      # ];
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

      lockdPort = 4001;
      mountdPort = 4002;
      statdPort = 4000;

      # extraNfsdConfig = '''';

      exports = ''
        /rpool/enc/transfers 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
      '';
    };
  };

  # NFS sharing
  fileSystems = {
    ### SSD
    "/flash/enc/personal" = {
      device = "flash/enc/personal";
      fsType = "zfs";
    };

    "/flash/enc/personal/documents" = {
      device = "flash/enc/personal/documents";
      fsType = "zfs";
    };

    "/flash/enc/personal/immich-library" = {
      device = "flash/enc/personal/immich-library";
      fsType = "zfs";
    };

    "/flash/enc/personal/photos" = {
      device = "flash/enc/personal/photos";
      fsType = "zfs";
    };

    "/flash/enc/personal/videos" = {
      device = "flash/enc/personal/videos";
      fsType = "zfs";
    };

    ### HDD
    "/rpool/enc/personal" = {
      device = "rpool/enc/personal";
      fsType = "zfs";
    };

    "/rpool/enc/personal/documents" = {
      device = "rpool/enc/personal/documents";
      fsType = "zfs";
    };

    "/rpool/enc/personal/paperless-media" = {
      device = "rpool/enc/personal/paperless-media";
      fsType = "zfs";
    };

    "/rpool/enc/transfers" = {
      device = "rpool/enc/transfers";
      fsType = "zfs";
    };

    "/rpool/unenc/apps" = {
      device = "rpool/unenc/apps";
      fsType = "zfs";
    };

    "/rpool/unenc/apps/kubernetes" = {
      device = "rpool/unenc/apps/kubernetes";
      fsType = "zfs";
    };

    "/rpool/unenc/apps/nixos" = {
      device = "rpool/unenc/apps/nixos";
      fsType = "zfs";
    };

    "/rpool/unenc/caches" = {
      device = "rpool/unenc/caches";
      fsType = "zfs";
    };

    "/rpool/unenc/dbs" = {
      device = "rpool/unenc/dbs";
      fsType = "zfs";
    };

    "/rpool/unenc/dbs/mysql" = {
      device = "rpool/unenc/dbs/mysql";
      fsType = "zfs";
    };

    "/rpool/unenc/dbs/psql" = {
      device = "rpool/unenc/dbs/psql";
      fsType = "zfs";
    };

    "/rpool/unenc/dbs/redis" = {
      device = "rpool/unenc/dbs/redis";
      fsType = "zfs";
    };

    "/rpool/unenc/media" = {
      device = "rpool/unenc/media";
      fsType = "zfs";
    };

    "/rpool/unenc/vms" = {
      device = "rpool/unenc/vms";
      fsType = "zfs";
    };
  };

  environment.systemPackages = with pkgs; [
    zfs
    zfstools
  ];
}
