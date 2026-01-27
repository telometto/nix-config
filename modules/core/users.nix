{
  lib,
  pkgs,
  VARS,
  config,
  ...
}:
let
  # Filter users based on per-host enablement (sys.users.<username>.enable)
  enabledUsers = lib.filterAttrs (
    _roleName: userData: config.sys.users.${userData.user}.enable or true
  ) VARS.users;
in
{
  # Create NixOS users from VARS.users
  # Transform from role-keyed (zeno, other) to username-keyed (zeno, <other's username>)
  # Only create users enabled for this host via sys.users.<username>.enable
  users = {
    mutableUsers = false;

    users = lib.mapAttrs' (
      _roleName: userData:
      lib.nameValuePair userData.user {
        inherit (userData) description isNormalUser hashedPassword group;
        shell = lib.mkForce pkgs.zsh;
        extraGroups = lib.mkDefault userData.extraGroups;
        openssh.authorizedKeys.keys = [
          userData.sshPubKey
          userData.gpgSshPubKey
        ];
      }
    ) enabledUsers;
  };
}
