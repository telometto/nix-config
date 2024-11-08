# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  xdg.portal.enable = true; # Needs to be enabled for Flatpak to work

  services.flatpak = {
    enable = true;
  };

  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];

    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Uncomment the line below to install system-wide
  environment.systemPackages = with pkgs; [ flatpak ];
}
