# Host-specific user overrides for snowfall
{ lib, pkgs, ... }:
{
  # Snowfall-specific user configuration
  # These settings will be applied to all users on this host

  # Example overrides:
  # hm.programs.development.extraPackages = with pkgs; [ snowfall-specific-tool ];
  # programs.git.extraConfig.snowfall = "specific-setting";

  hm = {
    programs = {
      development.extraPackages = [
        pkgs.vscode
        # pkgs.jetbrains.idea-community-bin # disabled until lidbm issue has been solved
      ];
    };
  };
}
