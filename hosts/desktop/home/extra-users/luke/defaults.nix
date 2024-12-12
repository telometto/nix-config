# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:

{
  users.extraUsers.${VARS.users.luke.user} = {
    isNormalUser = VARS.users.luke.isNormalUser;
    description = VARS.users.luke.description;
    extraGroups = VARS.users.luke.extraGroups;
    hashedPassword = VARS.users.luke.hashedPassword;
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
