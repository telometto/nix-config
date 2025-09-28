# Host-specific user overrides for blizzard (server)
{ lib, config, pkgs, VARS, ... }:
{
  # Blizzard-specific user configuration
  # These settings will be applied to all users on this host

  # Server-specific overrides:
  # hm.programs.terminal.extraPackages = with pkgs; [ server-tools ];
  # programs.git.extraConfig.blizzard = "server-setting";
}
