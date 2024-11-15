{ config, lib, pkgs, myVars, ... }:

{
  services.borgbackup = {
    jobs = {
      homeserver = {
        paths = myVars.general.testPath;
        environment.BORG_RSH = "ssh -i ${myVars.general.borgRsh}";
        repo = myVars.general.borgRepo;
        compression = "zstd,8";
        startAt = "daily";
        # user = myVars.mainUsers.server.user;

        encryption = {
          mode = "repokey-blake2";
          passCommand = "cat ${myVars.general.borgPassPath}";
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
        "/home/${myVars.mainUsers.server.user}"
        "/flash_temp"
        "/tank"
      ];
    };
    };
  */

  environment.systemPackages = with pkgs; [ borgbackup borgmatic ];
}
