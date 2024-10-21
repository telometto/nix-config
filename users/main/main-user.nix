# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users = {
    ${myVars.mainUsers.laptop.user} = {
      isNormalUser = myVars.mainUsers.laptop.isNormalUser;
      description = myVars.mainUsers.laptop.description;
      extraGroups = myVars.mainUsers.laptop.extraGroups;
  
      packages = with pkgs; [
        # Your packages here
      ];
  
      openssh.authorizedKeys.keys = [
        #myVars.general.openSSHPubKey
        myVars.general.openSSHGPGPubKey
      ];
    };
  };
}
