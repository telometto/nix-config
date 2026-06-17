# Host-specific user overrides for snowfall
{
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [ ./ssh-common.nix ];

  # Snowfall-specific user configuration
  # These settings will be applied to all users on this host
  hm = {
    programs = {
      browsers.chromium.enable = lib.mkForce false;

      gaming.lutris.enable = true;
    };
  };
}
