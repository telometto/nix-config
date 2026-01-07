{ lib, config, ... }:
let
  cfg = config.sys.services.zfs or { };
in
{
  options.sys.services.zfs.enable = lib.mkEnableOption "ZFS service helpers (scrub/snapshot/trim)";

  config = lib.mkIf cfg.enable {
    services.zfs = {
      autoScrub.enable = lib.mkDefault true;
      autoSnapshot.enable = lib.mkDefault false;
      trim.enable = lib.mkDefault true;
    };
  };
}
