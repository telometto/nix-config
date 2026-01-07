{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.services.flatpak;
in
{
  options.sys.services.flatpak.enable = lib.mkEnableOption "Flatpak + auto add flathub repo";

  options.sys.services.flatpak.unitOverrides = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Extra attributes merged into systemd.services.flatpak-repo (owner extension point).";
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.enable = true;

    # NOTE: xdg.portal configuration is NOT done here.
    # Each desktop environment (GNOME, KDE/Plasma, Hyprland, etc.) should configure
    # its own portal in its respective module:
    # - GNOME: automatically configures xdg-desktop-portal-gnome
    # - KDE/Plasma: automatically configures xdg-desktop-portal-kde
    # - Hyprland: configured in modules/desktop/flavors/hyprland.nix
    #
    # See: https://nixos.org/manual/nixos/stable/#module-services-flatpak
    # and: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/config/xdg/portal.nix

    systemd.services.flatpak-repo = lib.mkMerge [
      {
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.flatpak ];
        script = ''
          flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
          flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo
          flatpak remote-add --if-not-exists --user cosmic https://apt.pop-os.org/cosmic/cosmic.flatpakrepo
        '';
      }
      cfg.unitOverrides
    ];
  };
}
