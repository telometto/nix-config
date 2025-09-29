{ lib, config, ... }:
let
  cfg = config.telometto.services.zfs or { };
in
{
  options.telometto.services.zfs.enable =
    lib.mkEnableOption "ZFS service helpers (scrub/snapshot/trim)";

  config = lib.mkIf cfg.enable {
    services.zfs = {
      autoScrub.enable = lib.mkDefault true;
      autoSnapshot.enable = lib.mkDefault false;
      trim.enable = lib.mkDefault true;
    };
  };
}
