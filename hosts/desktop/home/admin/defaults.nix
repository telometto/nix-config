# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:

{
  users.users.${VARS.users.admin.user} = {
    description = VARS.users.admin.description;
    isNormalUser = VARS.users.admin.isNormalUser;
    extraGroups = VARS.users.admin.extraGroups ++ lib.optionals (config.networking.hostName == VARS.systems.desktop.hostname) [ "openrazer" ];
    hashedPassword = VARS.users.admin.hashedPassword;
    shell = pkgs.zsh;

    packages = with pkgs; [
      # Your packages here
    ];

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };
}
