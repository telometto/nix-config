# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:

{
  users.users.${VARS.users.admin.user} = {
    isNormalUser = VARS.users.admin.isNormalUser;
    description = VARS.users.admin.description;
    extraGroups = VARS.users.admin.extraGroups;
    hashedPassword = VARS.users.admin.hashedPassword;
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
