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

  isValidUsername = username: builtins.isString username && username != "";
  isValidUid = uid: builtins.isInt uid && uid > 0;

  usernames = map (record: record.username) (
    lib.filter (record: isValidUsername record.username) userRecords
  );
  uids = map (record: record.uid) (lib.filter (record: isValidUid record.uid) userRecords);

  duplicateValues =
    values:
    lib.unique (
      lib.filter (
        value: value != null && lib.length (lib.filter (candidate: candidate == value) values) > 1
      ) values
    );

  duplicateUsernames = duplicateValues usernames;
  duplicateUids = duplicateValues uids;

  validSshPubKeyRegex = "(ssh-ed25519|sk-ssh-ed25519@openssh\\.com|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ecdsa-sha2-nistp256@openssh\\.com|ssh-rsa)[[:space:]]+[A-Za-z0-9+/]+={0,2}([[:space:]].*)?";

  isValidSshPubKey = key: builtins.isString key && builtins.match validSshPubKeyRegex key != null;

  validPasswordHashRegex = "\\$(1|2[abxy]|5|6|7|y|gy)\\$[^[:space:]:$]+\\$[^[:space:]:]+";

  isValidPasswordHash =
    hash:
    builtins.isString hash
    && builtins.match validPasswordHashRegex hash != null
    && hash != ""
    && hash != "<HASHED PW>"
    && hash != "changeme"
    && hash != "password";

  userAssertions = lib.concatMap (
    record:
    let
      label = if isValidUsername record.username then record.username else record.roleName;
      inherit (record) userData;
    in
    [
      {
        assertion = isValidUsername record.username;
        message = "VARS.users.${record.roleName}.user must be a non-empty string.";
      }
      {
        assertion = isValidUid record.uid;
        message = "VARS.users.${record.roleName} (${label}) must define a positive integer uid.";
      }
      {
        assertion = userData ? hashedPassword && isValidPasswordHash userData.hashedPassword;
        message = "VARS.users.${record.roleName} (${label}) must define a non-empty, non-placeholder crypt-style hashedPassword. Do not use routine password expiry; rotate this hash only after compromise, account ownership changes, suspected reuse, weak/old password discovery, or lost device.";
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
    isValidUsername username && (config.sys.users.${username}.enable or false)
  ) varsUsers;
in
{
  assertions = [
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
