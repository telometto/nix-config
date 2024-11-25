# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users.${myVars.users.admin.user} = {
    isNormalUser = myVars.users.admin.isNormalUser;
    description = myVars.users.admin.description;
    extraGroups = myVars.users.admin.extraGroups;
    hashedPassword = myVars.users.admin.hashedPassword;
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
