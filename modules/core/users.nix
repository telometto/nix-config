# Automatically imported
{
  lib,
  pkgs,
  VARS,
  ...
}:
{
  # Create NixOS users from VARS.users
  # Transform from role-keyed (zeno, other) to username-keyed (zeno, <other's username>)
  users.users = lib.mapAttrs' (
    _roleName: userData:
    lib.nameValuePair userData.user {
      inherit (userData) description isNormalUser hashedPassword;
      shell = lib.mkForce pkgs.zsh;
      extraGroups = lib.mkDefault userData.extraGroups;
      openssh.authorizedKeys.keys = [
        userData.sshPubKey
        userData.gpgSshPubKey
      ];
    }
  ) VARS.users;
}
