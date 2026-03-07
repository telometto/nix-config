{ config, VARS, ... }:
let
  borgKnownHostsFile = "/home/${VARS.users.zeno.user}/.ssh/known_hosts-borg-blizzard";
in
{
  sys.services.borgbackup = {
    enable = false;

    jobs.homeserver = {
      paths = [ "/home/${VARS.users.zeno.user}" ];
      environment.BORG_RSH = "ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${borgKnownHostsFile} -i /home/${VARS.users.zeno.user}/.ssh/borg-blizzard";
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
