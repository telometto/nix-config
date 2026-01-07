{ lib, config, ... }:
let
  cfg = config.sys.services.borgbackup or { };
in
{
  options.sys.services.borgbackup = {
    enable = lib.mkEnableOption "BorgBackup jobs";

    jobs = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Map of borgbackup jobs to configure under services.borgbackup.jobs";
    };
  };

  config = lib.mkIf cfg.enable { services.borgbackup.jobs = cfg.jobs; };
}
