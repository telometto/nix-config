# Run `ls -l /dev/disk/by-id/ | grep -i nvme` on blizzard and substitute the
# correct by-id path before running disko.
#
# Existing pools (rpool, tank, flash) live on separate HDD/SSD disks — they
# are NOT modelled here and will not be touched by disko.  They continue to be
# imported at boot via boot.zfs.extraPools in hosts/blizzard/boot.nix.
#
# Swap deliberately sits outside the ZFS pool (plain partition) to avoid the
# well-known ZFS-on-ZVOL deadlock under memory pressure.
{ ... }:
{
  disko.devices = {
    disk.system = {
      type = "disk";
      device = "/dev/disk/by-id/<TBD: nvme-…>";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = {
            size = "8G";
            content = {
              type = "swap";
              discardPolicy = "both";
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "zroot";
            };
          };
        };
      };
    };

    zpool.zroot = {
      type = "zpool";
      mode = ""; # single-vdev — no mirror/raidz on a single NVMe
      rootFsOptions = {
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        atime = "off";
        canmount = "off";
        mountpoint = "none";
        "com.sun:auto-snapshot" = "false";
      };
      options = {
        ashift = "12";
        autotrim = "on";
      };
      datasets = {
        "root" = {
          type = "zfs_fs";
          mountpoint = "/";
          options.mountpoint = "legacy";
        };
        "nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options = {
            mountpoint = "legacy";
            atime = "off";
            "com.sun:auto-snapshot" = "false";
          };
        };
        "home" = {
          type = "zfs_fs";
          mountpoint = "/home";
          options.mountpoint = "legacy";
        };
        "var" = {
          type = "zfs_fs";
          mountpoint = "/var";
          options = {
            mountpoint = "legacy";
            "com.sun:auto-snapshot" = "false";
          };
        };
        "var/log" = {
          type = "zfs_fs";
          mountpoint = "/var/log";
          options.mountpoint = "legacy";
        };
        "tmp" = {
          type = "zfs_fs";
          mountpoint = "/tmp";
          options = {
            mountpoint = "legacy";
            "com.sun:auto-snapshot" = "false";
            sync = "disabled";
          };
        };
      };
    };
  };
}
