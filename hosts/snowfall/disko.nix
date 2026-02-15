_: {
  disko.devices = {
    disk = {
      system = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_500GB_S5GYNX0RC12209K";
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
                  "@log" = {
                    mountpoint = "/var/log";
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

      data = {
        type = "disk";
        destroy = false; # Protect existing data from accidental wipes
        device = "/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7685F0CD20";
        content = {
          type = "gpt";
          partitions = {
            personal = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@media" = {
                    mountpoint = "/run/media/zeno/personal/media";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@documents" = {
                    mountpoint = "/run/media/zeno/personal/documents";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@backups" = {
                    mountpoint = "/run/media/zeno/personal/backups";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@games" = {
                    mountpoint = "/run/media/zeno/personal/games";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
