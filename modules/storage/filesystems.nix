{ lib, config, ... }:
let
  cfg = config.sys.storage.filesystems;
in
{
  options.sys.storage.filesystems = {
    enable = lib.mkEnableOption "BTRFS filesystem management";

    baseUser = lib.mkOption {
      type = lib.types.str;
      default = "zeno";
      description = "Base username for /run/media paths";
    };

    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            device = lib.mkOption {
              type = lib.types.str;
              description = "Device UUID (without /dev/disk/by-uuid/ prefix)";
            };

            mountPoint = lib.mkOption {
              type = lib.types.str;
              description = "Mount point name (will be under /run/media/\${baseUser}/)";
            };

            options = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "defaults" ];
              description = "Mount options (include 'nofail' for non-critical mounts)";
            };
          };
        }
      );

      default = { };
      description = "BTRFS filesystem mounts";
    };

    autoScrub = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic BTRFS scrubbing";
      };

      interval = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "Scrub interval";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems = lib.mapAttrs' (
      _: mount:
      lib.nameValuePair "/run/media/${cfg.baseUser}/${mount.mountPoint}" {
        device = "/dev/disk/by-uuid/${mount.device}";
        fsType = "btrfs";
        inherit (mount) options;
      }
    ) cfg.mounts;

    boot = {
      supportedFilesystems = lib.mkDefault [ "btrfs" ];
      initrd.supportedFilesystems.btrfs = lib.mkDefault true;
    };

    services.btrfs.autoScrub = lib.mkIf cfg.autoScrub.enable {
      enable = lib.mkDefault true;
      inherit (cfg.autoScrub) interval;
    };
  };
}
