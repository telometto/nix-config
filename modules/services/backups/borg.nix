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

  environment.systemPackages = with pkgs; [ borgbackup ];
}
