# Host-specific user overrides for kaizer
# These settings will be applied to all users on kaizer host
{ lib, pkgs, ... }:
{
  # Kaizer runs GNOME - GNOME-specific settings will be auto-enabled
  # via the autoDesktopConfig in home-users.nix
  
  # Add any kaizer-specific configurations that apply to all users:
  # Example:
  # hm.programs.development.extraPackages = with pkgs; [ kaizer-specific-tool ];
  # programs.git.extraConfig.kaizer = "specific-setting";

  home.packages = [ pkgs.variety ];
}
