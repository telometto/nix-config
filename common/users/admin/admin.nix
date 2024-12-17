{ config, lib, pkgs, VARS, ... }:

{
  users.users.${VARS.users.admin.user} = {
    inherit (VARS.users.admin) description isNormalUser hashedPassword;

    extraGroups = VARS.users.admin.extraGroups ++ lib.optionals (config.networking.hostName == VARS.systems.desktop.hostName) [ "openrazer" ];

    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };
}
