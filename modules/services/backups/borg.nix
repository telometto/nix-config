{ config, lib, pkgs, myVars, ... }:

{
  services.borgbackup = lib.mkIf (config.networking.hostName == myVars.systems.server.hostname) {
    jobs = {
      homeserver = {
        paths = "/home/${myVars.server.adminUser.user}/borgtest";
        environment.BORG_RSH = "ssh -i $(cat${config.sops.secrets.borgRshFilePath.path})";
        repo = "ssh://$(cat ${config.sops.secrets.borgRepo.path})";
        compression = "zstd,8";
        startAt = "daily";

        encryption = {
          mode = "repokey-blake2";
          passCommand = "cat ${config.sops.secrets.borgKeyFilePath.path}";
        };
      };
    };
  };

  /* Template; on hold
    services.borgmatic = {
    enable = true;

    configurations = {};

    settings = {
      repositories = [
        {
          label = "flash";
          path = "";
        }
        {
          label = "tank";
          path = "";
        }
      ];

      source_directories = [
        "/home/${config.sops.secrets.users.admins.server.username}"
        "/flash_temp"
        "/tank"
      ];
    };
    };
  */

  environment.systemPackages = with pkgs; [ borgbackup borgmatic ];
}
