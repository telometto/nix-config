{ config, lib, pkgs, VARS, ... }:

{
  users.extraUsers.${VARS.users.frankie.user} = {
    description = VARS.users.frankie.description;
    isNormalUser = VARS.users.frankie.isNormalUser;
    extraGroups = VARS.users.frankie.extraGroups;
    hashedPassword = VARS.users.frankie.hashedPassword;
    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };
}
