# Keep every source record for validation. The lookup map intentionally keeps
# the first collision and falls back to the source role key for invalid logins.
{ lib, users }:
let
  isValidUsername = username: builtins.isString username && username != "";
  records = lib.mapAttrsToList (roleName: userData: {
    inherit roleName userData;
    username = userData.user or null;
    uid = userData.uid or null;
  }) users;
  byUsername = lib.listToAttrs (
    map (
      record:
      lib.nameValuePair (
        if isValidUsername record.username then record.username else record.roleName
      ) record.userData
    ) records
  );
in
{
  inherit records byUsername isValidUsername;
}
