# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users = {
    ${myVars.extraUsers.wife.user} = {
      isNormalUser = myVars.extraUsers.wife.isNormalUser;
      description = myVars.extraUsers.wife.description;
      extraGroups = myVars.extraUsers.wife.extraGroups;
  
      packages = with pkgs; [
        # Your packages here
      ];
  
      openssh.authorizedKeys.keys = [
        #myVars.general.openSSHPubKey
        myVars.general.openSSHGPGPubKey
      ];
    };
  };

  users.users = {
    ${myVars.extraUsers.brother-one.user} = {
      isNormalUser = myVars.extraUsers.brother-one.isNormalUser;
      description = myVars.extraUsers.brother-one.description;
      extraGroups = myVars.extraUsers.brother-one.extraGroups;
  
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
