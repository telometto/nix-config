{ config, lib, pkgs, myVars, ... }:

{
  services.borgbackup = {
    jobs = {
      homeserver = {
        paths = myVars.general.testPath;
        encryption = { mode = "repokey-blake2"; };
        #environment.BORG_RSH = myVars.general.borgRsh;
        repo = myVars.general.borgRepo;
        compression = "auto,lz4";
        startAt = "daily";
      };
    };
  };

  environment.systemPackages = with pkgs; [ borgbackup ];
}
