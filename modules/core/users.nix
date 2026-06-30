{
  lib,
  pkgs,
  VARS,
  config,
  ...
}:
let
  varsUsers = VARS.users or { };

  userRecords = lib.mapAttrsToList (roleName: userData: {
    inherit roleName userData;
    username = userData.user or null;
    uid = userData.uid or null;
  }) varsUsers;

  usernames = map (record: record.username) userRecords;
  uids = map (record: record.uid) (lib.filter (record: record.uid != null) userRecords);

  duplicateValues =
    values:
    lib.unique (
      lib.filter (
        value:
        value != null
        && lib.length (lib.filter (candidate: candidate == value) values) > 1
      ) values
    );

  duplicateUsernames = duplicateValues usernames;
  duplicateUids = duplicateValues uids;

  validSshPubKeyRegex =
    "(ssh-ed25519|sk-ssh-ed25519@openssh\\.com|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ecdsa-sha2-nistp256@openssh\\.com|ssh-rsa)[[:space:]]+[A-Za-z0-9+/]+={0,3}([[:space:]].*)?";

  isValidSshPubKey =
    key:
    builtins.isString key && builtins.match validSshPubKeyRegex key != null;

  isUsablePasswordHash =
    hash:
    builtins.isString hash
    && hash != ""
    && hash != "<HASHED PW>"
    && hash != "changeme"
    && hash != "password";

  userAssertions = lib.concatMap (
    record:
    let
      label = if record.username != null then record.username else record.roleName;
      userData = record.userData;
    in
    [
      {
        assertion = record.username != null && builtins.isString record.username && record.username != "";
        message = "VARS.users.${record.roleName}.user must be a non-empty string.";
      }
      {
        assertion = userData ? hashedPassword && isUsablePasswordHash userData.hashedPassword;
        message = "VARS.users.${record.roleName} (${label}) must define a non-empty, non-placeholder hashedPassword. Do not use routine password expiry; rotate this hash only after compromise, account ownership changes, suspected reuse, weak/old password discovery, or lost device.";
      }
      {
        assertion = userData ? sshPubKey && isValidSshPubKey userData.sshPubKey;
        message = "VARS.users.${record.roleName} (${label}) must define a valid bare OpenSSH public key in sshPubKey.";
      }
      {
        assertion = userData ? gpgSshPubKey && isValidSshPubKey userData.gpgSshPubKey;
        message = "VARS.users.${record.roleName} (${label}) must define a valid bare OpenSSH public key in gpgSshPubKey.";
      }
    ]
  ) userRecords;

  # Filter users based on per-host enablement (sys.users.<username>.enable)
  enabledUsers = lib.filterAttrs (
    _roleName: userData:
    let
      username = userData.user or null;
    in
    username != null && (config.sys.users.${username}.enable or false)
  ) varsUsers;
in
{
  assertions =
    [
      {
        assertion = duplicateUsernames == [ ];
        message = "VARS.users contains duplicate login names: ${lib.concatStringsSep ", " duplicateUsernames}";
      }
      {
        assertion = duplicateUids == [ ];
        message = "VARS.users contains duplicate UIDs: ${lib.concatStringsSep ", " (map builtins.toString duplicateUids)}";
      }
    ]
    ++ userAssertions;

  # Create NixOS users from VARS.users
  # Transform from role-keyed (zeno, other) to username-keyed (zeno, <other's username>)
  # Only create users enabled for this host via sys.users.<username>.enable
  users = {
    mutableUsers = false;

    users = lib.mapAttrs' (
      _roleName: userData:
      lib.nameValuePair userData.user {
        inherit (userData)
          description
          isNormalUser
          hashedPassword
          group
          ;
        uid = lib.mkIf (userData ? uid) userData.uid;
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
