# Automatically imported
{
  lib,
  pkgs,
  VARS,
  ...
}:
let
  inherit (VARS.users) admin;
in
{
  users.users.${admin.user} = {
    inherit (admin) description isNormalUser hashedPassword;
    shell = lib.mkForce pkgs.zsh;
    extraGroups = lib.mkDefault admin.extraGroups;
    openssh.authorizedKeys.keys = [
      admin.sshPubKey
      admin.gpgSshPubKey
    ];
  };

  telometto.home.systemUsers.${admin.user} = admin;
}
