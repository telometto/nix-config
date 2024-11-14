# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users.${myVars.mainUsers.desktop.user} = {
    isNormalUser = myVars.mainUsers.desktop.isNormalUser;
    description = myVars.mainUsers.desktop.description;
    extraGroups = myVars.mainUsers.desktop.extraGroups;
    shell = pkgs.zsh;

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      myVars.general.openSSHPubKey
      myVars.general.openSSHGPGPubKey
    ];
  };
}
