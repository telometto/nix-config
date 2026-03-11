{ lib, config, ... }:
let
  cfg = config.sys.services.maintenance;
in
{
  options.sys.services.maintenance = {
    enable = lib.mkEnableOption "Basic maintenance timers/services (always enables fstrim; optional subfeatures add firmware updates, zram, and removable-media helpers)";

    desktop.enable = lib.mkEnableOption "desktop-oriented removable-media helpers (devmon, gvfs, udisks2)";

    firmware.enable = lib.mkEnableOption "firmware updates via fwupd";

    zram = {
      enable = lib.mkEnableOption "compressed in-memory swap";

      algorithm = lib.mkOption {
        type = lib.types.str;
        default = "zstd";
        description = "Compression algorithm used by zram swap.";
      };

      memoryPercent = lib.mkOption {
        type = lib.types.ints.between 1 100;
        default = 25;
        description = "Maximum zram swap size as a percentage of total RAM.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      fstrim.enable = true;
      fwupd.enable = cfg.firmware.enable;
      devmon.enable = cfg.desktop.enable; # FIXME: udevil GCC 15 fix applied via overlay in overlays.nix due to udevil build failure - https://github.com/NixOS/nixpkgs/issues/475479
      gvfs.enable = cfg.desktop.enable;
      udisks2.enable = cfg.desktop.enable;
    };

    zramSwap = lib.mkIf cfg.zram.enable {
      enable = true;
      inherit (cfg.zram) algorithm memoryPercent;
    };
  };
}
