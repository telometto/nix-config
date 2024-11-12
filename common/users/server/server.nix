# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users.${myVars.mainUsers.server.user} = {
    isNormalUser = myVars.mainUsers.server.isNormalUser;
    description = myVars.mainUsers.server.description;
    extraGroups = myVars.mainUsers.server.extraGroups;

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      #myVars.general.openSSHPubKey
      myVars.general.openSSHGPGPubKey
    ];
  };
}
