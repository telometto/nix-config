# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users.${myVars.systems.server.adminUser.user} = {
    isNormalUser = myVars.systems.server.adminUser.isNormalUser;
    description = myVars.systems.server.adminUser.description;
    extraGroups = myVars.systems.server.adminUser.extraGroups;
    shell = pkgs.zsh;

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      myVars.users.admin.sshPubKey
      myVars.users.admin.gpgSshPubKey
    ];
  };
}
