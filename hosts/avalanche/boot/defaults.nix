{ config, lib, pkgs, VARS, ... }:
{
  # Bootloader
  boot = {
    supportedFilesystems = [ "nfs" ];

    initrd = {
      enable = true;
    };
  };

  systemd.mounts = [{
    type = "nfs";
    mountConfig = {
      options = "rw,noatime,nofail";
    };
    what = "192.168.2.100:/rpool/enc/transfers";
    where = "/home/zeno/Documents/mnt/server/transfers";
  }];

  systemd.automounts = [{
    wantedBy = [ "multi-user.target" ];
    automountConfig = {
      TimeoutIdleSec = "600";
    };
    where = "/home/zeno/Documents/mnt/server/transfers";
  }];

  # Services
  services = {
    rpcbind = { enable = lib.mkOptionDefault true; };
  };

  environment.systemPackages = with pkgs; [
    libnfs
    nfs-utils
    btrfs-progs
  ];
}
