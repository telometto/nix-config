# Common desktop services for desktop/laptop hosts
{ config, lib, pkgs, VARS, mylib, ... }:

{
  services = {
    # Printing is handled via shared/system.nix default

    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # udisks2 is enabled globally in shared/system.nix to also cover server
    # udisks2.enable = true;
    upower.enable = true;

    # Flatpak for desktop/laptop hosts
    flatpak.enable = true;
  };

  # XDG portal required for Flatpak; select DE-specific portal to avoid conflicts
  xdg.portal = {
    enable = true;
    extraPortals = let
      isGnome = (config.services.desktopManager.gnome.enable or false)
        || (config.services.xserver.desktopManager.gnome.enable or false);
      isPlasma = config.services.desktopManager.plasma6.enable or false;
    in lib.unique (with pkgs;
      (lib.optionals isGnome [ xdg-desktop-portal-gnome ]) ++
      (lib.optionals isPlasma [ kdePackages.xdg-desktop-portal-kde ]) ++
      (lib.optionals (!(isGnome || isPlasma)) [ xdg-desktop-portal-gtk ])
    );
  };

  # Ensure Flathub is configured once system reaches multi-user.target
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.flatpak pkgs.bash ];
    serviceConfig = {
      Type = "oneshot";
      ExecCondition = ''
        ${pkgs.bash}/bin/bash -c "! flatpak remotes --system | grep -q '^flathub$'"
      '';
    };
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Font configuration
  fonts.fontconfig.enable = true;

  # Intentionally no GUI apps here; prefer Home Manager for user applications
}
