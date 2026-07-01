# sys.users.*: Per-host user enablement control
# Provides options to selectively enable/disable users from VARS on each host
{ lib, VARS, ... }:
let
  # Generate an option for each user from VARS
  makeUserOption = username: _userData: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable ${username} user account on this host";
    };
  };

  # Create a submodule for each user in VARS
  userOptions = lib.mapAttrs makeUserOption (
    lib.listToAttrs (
      lib.mapAttrsToList (roleName: userData:
        let
          username = userData.user or null;
        in
        {
          name = if builtins.isString username && username != "" then username else roleName;
          value = userData;
        }
      ) (VARS.users or { })
    )
  );
in
{
  options.sys.users = userOptions;
}
