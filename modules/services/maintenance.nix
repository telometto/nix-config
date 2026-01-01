# OK
{ lib, config, ... }:
let
  cfg = config.telometto.services.maintenance;
in
{
  options.telometto.services.maintenance.enable =
    lib.mkEnableOption "Basic maintenance timers/services (fstrim, fwupd, zram, gvfs, udisks2)";
  config = lib.mkIf cfg.enable {
    services = {
      fstrim.enable = true;
      fwupd.enable = true;
      devmon.enable = true; # FIXME: udevil GCC 15 fix applied via overlay in overlays.nix due to udevil build failure - https://github.com/NixOS/nixpkgs/issues/475479
      gvfs.enable = true;
      udisks2.enable = true;
      zram-generator.enable = true;
    };
  };
}
