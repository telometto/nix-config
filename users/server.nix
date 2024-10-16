# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users.${myVars.server.user} = {
    isNormalUser = true;
    description = myVars.server.user;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" ];

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      myVars.server.openSSHPubKey
      myVars.server.openSSHGPGPubKey
    ];
  };
}
