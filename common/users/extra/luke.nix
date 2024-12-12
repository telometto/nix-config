{ config, lib, pkgs, VARS, ... }:

{
  users.extraUsers.${VARS.users.luke.user} = {
    description = VARS.users.luke.description;
    isNormalUser = VARS.users.luke.isNormalUser;
    extraGroups = VARS.users.luke.extraGroups;
    hashedPassword = VARS.users.luke.hashedPassword;
    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };
}
