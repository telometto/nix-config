# Host-specific system configuration defaults
{
  config,
  lib,
  pkgs,
  VARS,
  ...
}:

{
  programs.virt-manager = {
    enable = true;
  };

  #environment.systemPackages = with pkgs; [
  #  virt-manager
  #  virt-manager-qt
  #];
}
