{ lib, pkgs, ... }:
{
  hardware.cpu.intel.updateMicrocode = true;

  boot = {
    # ZFS 2.4.x + kernel 6.18 causes swap cgroup crashes (lookup_swap_cgroup_id oops).
    # Pin to latest ZFS-compatible LTS kernel until upstream fixes land.
    kernelPackages = pkgs.linuxPackages_6_12;

    supportedFilesystems = [ "zfs" ];
    initrd.supportedFilesystems.zfs = true;

    zfs = {
      forceImportAll = true;
      requestEncryptionCredentials = true;
      devNodes = "/dev/disk/by-id";

      extraPools = [
        "tank"
        "rpool"
        "flash"
      ];
    };

    kernel.sysctl = {
      "net.ipv4.conf.all.src_valid_mark" = 1;
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.core.wmem_max" = 7500000;
      "net.core.rmem_max" = 7500000;
    };
  };
}
