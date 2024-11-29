# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users.${myVars.users.serverAdmin.user} = {
    isNormalUser = myVars.users.serverAdmin.isNormalUser;
    description = myVars.users.serverAdmin.description;
    extraGroups = myVars.users.serverAdmin.extraGroups;
    hashedPassword = myVars.users.serverAdmin.hashedPassword;
    shell = pkgs.zsh;

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      myVars.users.serverAdmin.sshPubKey
      myVars.users.serverAdmin.gpgSshPubKey
    ];
  };
}
