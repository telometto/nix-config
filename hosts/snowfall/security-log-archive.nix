{ config, lib, ... }:
let
  cfg = config.sys.services.securityLogArchive;
in
{
  sys.services.securityLogArchive = {
    sourceHost = "blizzard";
    repositoryName = "blizzard-security-logs";
    repositoryId = null;
    admin.enable = false;
  };
  sops.secrets = lib.mkIf cfg.admin.enable {
    "security-log-archive/admin-ssh" = {
      mode = "0400";
    };
    "security-log-archive/password" = {
      mode = "0400";
    };
  };
}
