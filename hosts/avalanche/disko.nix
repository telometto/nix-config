# Run `ls -l /dev/disk/by-id/ | grep -i nvme` on avalanche and substitute the
# correct by-id path before running disko.
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
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@var" = {
                  mountpoint = "/var";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@tmp" = {
                  mountpoint = "/tmp";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@swap" = {
                  mountpoint = "/.swapvol";
                  swap.swapfile.size = "8G";
                };
              };
            };
          };
        };
      };
    };
  };
}
