{ config, lib, pkgs, myVars, ... }:

{
  services.borgbackup = lib.mkIf (config.networking.hostName == myVars.systems.server.hostname) {
    jobs = {
      homeserver = {
        paths = "/home/${myVars.users.serverAdmin.user}/borgtest";
        # environment.BORG_RSH = "ssh -o 'StrictHostKeyChecking=no' -i ${config.sops.secrets.borgRshFilePath.path}";
        environment.BORG_RSH = "ssh -o 'StrictHostKeyChecking=no' -i ${config.sops.secrets."general.borgRshFilePath".path}";
        repo = "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo";
        compression = "zstd,8";
        startAt = "daily";

        encryption = {
          mode = "repokey-blake2";
          # passCommand = "cat ${config.sops.secrets.borgKeyFilePath.path}";
          passCommand = "cat ${config.sops.secrets."general/borgKeyFilePath".path}";
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
