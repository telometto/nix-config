# Generic BorgBackup jobs abstraction
{ lib, config, pkgs, ... }:
let
  inherit (lib) mkOption types mkIf concatStringsSep;
  cfg = config.my.backups;
  mkEnv = job: (job.environment or { }) // (if job.identityFile != null then { BORG_RSH = "ssh -o 'StrictHostKeyChecking=no' -i ${job.identityFile}"; } else { });
  mkJob = name: job: {
    paths = job.paths;
    repo = job.repo;
    compression = job.compression;
    startAt = job.startAt;
    environment = mkEnv job;
    encryption = {
      mode = job.encryption.mode;
      passCommand = job.encryption.passCommand;
    };
    prune = job.prune; # optional attrset
  };
  jobsAttr = lib.mapAttrs mkJob cfg.jobs;
in
{
  options.my.backups = {
    jobs = mkOption {
      type = types.attrsOf (types.submodule ({ ... }: {
        options = {
          paths = mkOption { type = types.either types.str (types.listOf types.str); description = "Path(s) to back up"; };
          repo = mkOption { type = types.str; description = "Borg repository URL"; };
          compression = mkOption { type = types.str; default = "zstd,8"; };
          startAt = mkOption { type = types.str; default = "daily"; };
          identityFile = mkOption { type = types.nullOr types.path; default = null; description = "SSH key file"; };
          encryption = mkOption {
            type = types.submodule ({ ... }: {
              options = {
                mode = mkOption { type = types.str; default = "repokey-blake2"; };
                passCommand = mkOption { type = types.str; description = "Command printing passphrase"; };
              };
            });
            description = "Borg encryption settings";
          };
          environment = mkOption { type = types.attrs; default = { }; };
          prune = mkOption { type = types.attrs; default = { }; description = "Prune policy attrset"; };
        };
      }));
      default = { };
      description = "Declared Borg jobs";
    };
  };

  config = mkIf (cfg.jobs != { }) {
    services.borgbackup.jobs = jobsAttr;
  };
}
