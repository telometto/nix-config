# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  users.users.${myVars.users.admin.user} = {
    description = myVars.users.admin.description;
    isNormalUser = myVars.users.admin.isNormalUser;
    extraGroups = myVars.users.admin.extraGroups ++ lib.optionals (config.networking.hostName == myVars.systems.desktop.hostname) [ "openrazer" ];
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
