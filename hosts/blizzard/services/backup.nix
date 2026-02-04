{ config, VARS, ... }:
{
  sys.services.borgbackup = {
    enable = false;

    jobs.homeserver = {
      paths = [ "/home/${VARS.users.zeno.user}" ];
      environment.BORG_RSH = "ssh -o 'StrictHostKeyChecking=no' -i /home/${VARS.users.zeno.user}/.ssh/borg-blizzard";
      repo = config.sys.secrets.borgRepo or "ssh://iu445agy@iu445agy.repo.borgbase.com/./repo";
      compression = "zstd,8";
      startAt = "daily";

      encryption = {
        mode = "repokey-blake2";
        passCommand = "cat ${config.sys.secrets.borgKeyFile}";
      };
    };
  };
}
