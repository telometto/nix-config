# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

lib.mkIf (config.networking.hostName != myVars.server.hostname)
{
  programs.virt-manager = {
    enable = true;
  };

  #environment.systemPackages = with pkgs; [
  #  virt-manager
  #  virt-manager-qt
  #];
}
