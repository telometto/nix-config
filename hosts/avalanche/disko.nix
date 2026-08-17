{ lib, ... }:
let
  # The generated hardware config shows Avalanche's system disk is NVMe, but
  # verify this on the installer and replace it with the matching by-id path
  # before running a destructive Disko command.
  systemDisk = "/dev/disk/by-id/nvme-KINGSTON_SA2000M81000G_50026B72824AE629";
in
{
  boot = {
    supportedFilesystems = lib.mkAfter [ "btrfs" ];
    initrd.supportedFilesystems.btrfs = true;
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
    # All listed paths are subvolumes of this filesystem. Scrub its top-level
    # mount once rather than scheduling duplicate scrubs for every subvolume.
    fileSystems = [ "/" ];
  };

  disko.devices.disk.system = {
    type = "disk";
    device = systemDisk;
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

              # A separate subvolume gives snapper or manual btrfs snapshots
              # a stable location outside the root subvolume.
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };

              # Disko creates the swapfile in a dedicated subvolume so it is
              # not included in snapshots and remains NOCOW-compatible.
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
}
