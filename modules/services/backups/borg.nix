{ config, lib, pkgs, ... }:

{
  services.borgbackup = {
    jobs = {
      homeserver = {
        paths = config.sops.secrets.testPath.path;
        environment.BORG_RSH = "ssh -i ${config.sops.secrets.borgRshFilePath.path}";
        repo = "ssh://${config.sops.secrets.general.borgRepo.path}";
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
