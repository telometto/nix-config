{ lib, config, ... }:
let
  cfg = config.sys.services.maintenance;
in
{
  options.sys.services.maintenance.enable =
    lib.mkEnableOption "Basic maintenance timers/services (fstrim, fwupd, zram, gvfs, udisks2)";
  config = lib.mkIf cfg.enable {
    services = {
      fstrim.enable = true;
      fwupd.enable = true;
      devmon.enable = true;
      gvfs.enable = true;
      udisks2.enable = true;
      zram-generator.enable = true;
    };
  };
}
