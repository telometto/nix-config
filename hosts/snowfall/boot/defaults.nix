/*
 * This NixOS configuration file sets up filesystem defaults for a desktop machine.
 * It includes configurations for the bootloader, filesystems, and services related to Btrfs and NFS.
 * Additionally, it specifies system packages required for NFS and Btrfs operations.
 *
 * - Bootloader: Configures supported filesystems for the bootloader.
 * - Filesystems: Defines mount points for Btrfs and NFS filesystems.
 * - Services: Enables and configures Btrfs auto-scrubbing service.
 * - System Packages: Installs necessary packages for NFS and Btrfs support.
*/

{ config, lib, pkgs, VARS, ... }:
let
  DRIVE_BASE_PATH = "/run/media/${VARS.users.admin.user}";
in
{
  # Bootloader
  boot = {
    supportedFilesystems = [ "btrfs" ];
  };

  # Filesystems
  fileSystems = {
    "${DRIVE_BASE_PATH}/personal" = {
      device = "/dev/disk/by-uuid/76177a35-e3a1-489f-9b21-88a38a0c1d3e";
      fsType = "btrfs";
      options = [ "defaults" ];
    };

    "${DRIVE_BASE_PATH}/samsung" = {
      device = "/dev/disk/by-uuid/e7e653c3-361c-4fb2-a65e-13fdcb1e6e25";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };

    # "${DRIVE_BASE_PATH}/personal/shares" = {
    #   device = "192.168.2.100:/flash_temp/nfsshare";
    #   fsType = "nfs";
    #   options = [
    #     "x-systemd.automount"
    #     "x-systemd.idle-timeout=600"
    #     "noauto"
    #     "nofail"
    #   ];
    # };
  };

  # Services
  services = {
    rpcbind = { enable = lib.mkOptionDefault true; };

    btrfs = {
      autoScrub = {
        enable = true;

        interval = "weekly";
      };
    };

    nfs.server = {
      enable = true;

      lockdPort = 4001;
      mountdPort = 4002;
      statdPort = 4000;

      # extraNfsdConfig = '''';

      exports = ''
        /run/media/zeno/personal/nfs-oldie 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    libnfs
    nfs-utils
    btrfs-progs
  ];
}
