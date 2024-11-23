# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  programs.virt-manager = {
    enable = true;
  };

  #environment.systemPackages = with pkgs; [
  #  virt-manager
  #  virt-manager-qt
  #];
}
