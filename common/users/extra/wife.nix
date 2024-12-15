{ config, lib, pkgs, VARS, ... }:

{
  users.extraUsers.${VARS.users.wife.user} = {
    description = VARS.users.wife.description;
    isNormalUser = VARS.users.wife.isNormalUser;
    extraGroups = VARS.users.wife.extraGroups;
    hashedPassword = VARS.users.wife.hashedPassword;
    shell = pkgs.zsh;

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };
}
