# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:

{
  users.users.${VARS.users.serverAdmin.user} = {
    isNormalUser = VARS.users.serverAdmin.isNormalUser;
    description = VARS.users.serverAdmin.description;
    extraGroups = VARS.users.serverAdmin.extraGroups;
    hashedPassword = VARS.users.serverAdmin.hashedPassword;
    shell = pkgs.zsh;

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      VARS.users.serverAdmin.sshPubKey
      VARS.users.serverAdmin.gpgSshPubKey
    ];
  };
}
