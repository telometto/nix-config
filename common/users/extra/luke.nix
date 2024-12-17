{ config, lib, pkgs, VARS, ... }:

{
  users.extraUsers.${VARS.users.luke.user} = {
    inherit (VARS.users.luke) description isNormalUser extraGroups hashedPassword;
    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };
}
