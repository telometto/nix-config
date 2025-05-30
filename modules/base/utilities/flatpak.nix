/**
 * This NixOS module configures Flatpak support on the system. It enables the necessary
 * xdg portal for Flatpak to function correctly, sets up the Flatpak service, and adds
 * the Flathub repository if it does not already exist. Additionally, it provides an
 * option to install Flatpak system-wide by uncommenting the relevant line.
 */

{ config, lib, pkgs, VARS, ... }:

{
  # xdg.portal = {
  #   enable = true; # Needs to be enabled for Flatpak to work

  #   # wlr.enable = true;

  #   configPackages = with pkgs; [ kdePackages.xdg-desktop-portal-kde ];
  #   xdgOpenUsePortal = true;

  #   extraPortals = with pkgs; [
  #     # xdg-desktop-portal-wlr
  #     xdg-desktop-portal-gtk
  #   ];
  # };

  services.flatpak = { enable = true; };

  # Add Flathub repository if it does not already exist
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];

    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };
}
