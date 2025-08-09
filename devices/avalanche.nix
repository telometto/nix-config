# Avalanche (Laptop) device module
{ config, lib, pkgs, VARS, ... }:
let
  constants = import ../shared/constants.nix;
  nfsServerIP = constants.network.nfsServerIP;
  transfersExport = constants.nfs.transfersExport;
  adminUser = VARS.users.admin.user;
in {
  hardware = {
    cpu.intel.updateMicrocode = true;
    bluetooth.enable = true;
  };

  boot.plymouth.enable = true;

  environment.systemPackages = with pkgs; [ ];

  networking = {
    inherit (VARS.systems.laptop) hostName hostId;
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
      where = "/home/${adminUser}/Documents/mnt/server/transfers";
    }];

    automounts = [{
      wantedBy = [ "multi-user.target" ];
      automountConfig.TimeoutIdleSec = "600";
      where = "/home/${adminUser}/Documents/mnt/server/transfers";
    }];
  };
}
