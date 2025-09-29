{ lib, config, ... }:
let
  cfg = config.telometto.services.borgbackup or { };
in
{
  options.telometto.services.borgbackup = {
    enable = lib.mkEnableOption "BorgBackup jobs";

    # Thin pass-through for jobs; shape mirrors services.borgbackup.jobs
    jobs = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Map of borgbackup jobs to configure under services.borgbackup.jobs";
    };
  };

  config = lib.mkIf cfg.enable { services.borgbackup.jobs = cfg.jobs; };
}
