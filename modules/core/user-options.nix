# sys.users.*: Per-host user enablement control
# Provides options to selectively enable/disable users from VARS on each host
{ lib, VARS, ... }:
let
  userRegistry = import ../../lib/user-registry.nix {
    inherit lib;
    users = VARS.users or { };
  };

  # Generate an option for each user from VARS
  makeUserOption = username: _userData: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable ${username} user account on this host";
    };
  };

  # Create a submodule for each user in VARS
  userOptions = lib.mapAttrs makeUserOption userRegistry.byUsername;
in
{
  options.sys.users = userOptions;
}
