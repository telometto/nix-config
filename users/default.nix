# User definitions
{ config, lib, pkgs, VARS, ... }:

{
  # Admin user - present on all systems
  users.users.${VARS.users.admin.user} = {
    inherit (VARS.users.admin) description isNormalUser hashedPassword;

    extraGroups = VARS.users.admin.extraGroups ++ lib.optionals
      (config.networking.hostName == VARS.systems.desktop.hostName)
      [ "openrazer" ];

    shell = pkgs.zsh;

    openssh.authorizedKeys.keys =
      [ VARS.users.admin.sshPubKey VARS.users.admin.gpgSshPubKey ];
  };

  # Extra users - configure as needed per host
  # Francesco
  users.users.${VARS.users.frankie.user} = {
    inherit (VARS.users.frankie)
      description isNormalUser hashedPassword extraGroups;
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys =
      [ VARS.users.admin.sshPubKey VARS.users.admin.gpgSshPubKey ];
  };

  # Gianluca (Luke)
  users.users.${VARS.users.luke.user} = {
    inherit (VARS.users.luke)
      description isNormalUser hashedPassword extraGroups;
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys =
      [ VARS.users.admin.sshPubKey VARS.users.admin.gpgSshPubKey ];
  };

  # Wife
  users.users.${VARS.users.wife.user} = {
    inherit (VARS.users.wife)
      description isNormalUser hashedPassword extraGroups;
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys =
      [ VARS.users.admin.sshPubKey VARS.users.admin.gpgSshPubKey ];
  };
}
