# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

lib.mkIf (config.networking.hostName != "blizzard")
{
  programs.virt-manager = {
    enable = true;
  };

  #environment.systemPackages = with pkgs; [
  #  virt-manager
  #  virt-manager-qt
  #];
}
