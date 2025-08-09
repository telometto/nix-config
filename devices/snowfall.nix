# Snowfall (Desktop) device module
{ config, lib, pkgs, VARS, ... }:
let
  constants = import ../shared/constants.nix;
  nfsServerIP = constants.network.nfsServerIP;
  transfersExport = constants.nfs.transfersExport;
  adminUser = VARS.users.admin.user;
  lanCIDR = constants.network.lanCIDR;
in
{
  hardware = {
    cpu.amd.updateMicrocode = true;
    graphics = { enable = true; enable32Bit = true; };
    amdgpu.initrd.enable = true;
    openrazer = { enable = true; users = [ adminUser ]; };
    bluetooth.enable = false;
  };

  boot = {
    kernel.sysctl = {
      "fs.inotify.max_user_watches" = 655360;
      "fs.file-max" = 6815744;
    };
    plymouth.enable = true;
  };

  # Only device-unique packages (leave common desktop/gaming packages to shared/system-packages)
  environment.systemPackages = with pkgs; [ libnfs nfs-utils btrfs-progs ];

  networking = {
    inherit (VARS.systems.desktop) hostName hostId;
    networkmanager.enable = true;
    wireless.enable = false;
    useNetworkd = lib.mkForce false;
    useDHCP = lib.mkForce true;
  };

  systemd = {
    mounts = [{
      type = "nfs";
      mountConfig.options = "rw,noatime,nofail";
      what = "${nfsServerIP}:${transfersExport}";
      where = "/run/media/${adminUser}/personal/transfers";
    }];

    automounts = [{
      wantedBy = [ "multi-user.target" ];
      automountConfig.TimeoutIdleSec = "600";
      where = "/run/media/${adminUser}/personal/transfers";
    }];
  };

  fileSystems = {
    "/run/media/${adminUser}/personal" = {
      device = "/dev/disk/by-uuid/76177a35-e3a1-489f-9b21-88a38a0c1d3e";
      fsType = "btrfs";
      options = [ "defaults" ];
    };
    "/run/media/${adminUser}/samsung" = {
      device = "/dev/disk/by-uuid/e7e653c3-361c-4fb2-a65e-13fdcb1e6e25";
      fsType = "btrfs";
      options = [ "defaults" "nofail" ];
    };
  };

  services = {
    teamviewer.enable = true;
    btrfs.autoScrub = {
      enable = true;
      interval = "weekly";
      fileSystems = [
        "/run/media/${adminUser}/personal"
        "/run/media/${adminUser}/samsung"
      ];
    };
  };
}
