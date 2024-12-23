{ config, lib, pkgs, VARS, ... }:

{
  users.extraUsers.${VARS.users.frankie.user} = {
    inherit (VARS.users.frankie) description isNormalUser extraGroups hashedPassword;

    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };
}
