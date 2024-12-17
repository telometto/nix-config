# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:

{
  users.extraUsers.${VARS.users.frankie.user} = {
    isNormalUser = VARS.users.frankie.isNormalUser;
    description = VARS.users.frankie.description;
    extraGroups = VARS.users.frankie.extraGroups;
    hashedPassword = VARS.users.frankie.hashedPassword;
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
