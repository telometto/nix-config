# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  xdg.portal.enable = true; # Needs to be enabled for Flatpak to work

  services.flatpak = {
    enable = true;
  };

  # Uncomment the line below to install system-wide
  environment.systemPackages = with pkgs; [ flatpak ];
}
