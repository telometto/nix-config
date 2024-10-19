# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users = {
    ${myVars.laptop.user} = {
      isNormalUser = true;
      description = myVars.laptop.description;
      extraGroups = [ "wheel" "networkmanager" "libvirtd" ];
  
      packages = with pkgs; [
        # Your packages here
      ];
  
      openssh.authorizedKeys.keys = [
        #myVars.laptop.openSSHPubKey
        myVars.laptop.openSSHGPGPubKey
      ];
    };

    ${myVars.extraUsers.user} = {
      isNormalUser = true;
      description = myVars.extraUsers.description;
      extraGroups = [ ];
  
      packages = with pkgs; [
        # Your packages here
      ];
  
      openssh.authorizedKeys.keys = [
        #myVars.laptop.openSSHPubKey
        myVars.laptop.openSSHGPGPubKey
      ];
    };
  };
}
