# Filesystem configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  # Bootloader
  boot = {
    supportedFilesystems = [ "btrfs" ]; # Upon changing to btrfs; add here
  };

  fileSystems = {
    "/run/media/${myVars.mainUsers.desktop.user}/personal" = {
      device = "/dev/disk/by-uuid/76177a35-e3a1-489f-9b21-88a38a0c1d3e";
      fsType = "btrfs";
      options = [ "defaults" ];
    };

    "/run/media/${myVars.mainUsers.desktop.user}/samsung" = {
      device = "/dev/disk/by-uuid/e7e653c3-361c-4fb2-a65e-13fdcb1e6e25";
      fsType = "btrfs";
      options = [ "defaults" ];
    };

    "/run/media/${myVars.mainUsers.desktop.user}/personal/shares" = {
      device = "192.168.2.100:/flash_temp/nfsshare";
      fsType = "nfs";
      options = [ "nofail" ];
    };
  };

  services = {
    btrfs = {
      autoScrub = {
        enable = true;

        interval = "weekly";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    libnfs
    nfs-utils
    btrfs-progs
  ];
}
