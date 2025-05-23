{ config, lib, pkgs, VARS, ... }:

{
  services.borgbackup = lib.mkIf (config.networking.hostName == VARS.systems.server.hostName) {
    jobs = {
      homeserver = {
        paths = "/home/${VARS.users.admin.user}";
        environment.BORG_RSH = "ssh -o 'StrictHostKeyChecking=no' -i /home/${VARS.users.admin.user}/.ssh/borg-blizzard";
        repo = "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo";
        compression = "zstd,8";
        startAt = "daily";

        encryption = {
          mode = "repokey-blake2";
          # passCommand = "cat ${config.sops.secrets."general/borgKeyFilePath".path}";
          passCommand = "cat /opt/sec/borg-file";
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

  sops.secrets = {
    "general/borgKeyFilePath" = { };
    "general/borgRepo" = { };
  };

  environment.systemPackages = with pkgs; [ borgbackup borgmatic ];
}
