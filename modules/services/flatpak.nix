# OK
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.flatpak;
in
{
  options.telometto.services.flatpak.enable = lib.mkEnableOption "Flatpak + auto add flathub repo";

  options.telometto.services.flatpak.unitOverrides = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Extra attributes merged into systemd.services.flatpak-repo (owner extension point).";
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.enable = true;

    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = lib.mkDefault [ pkgs.xdg-desktop-portal-gtk ];
      xdgOpenUsePortal = lib.mkDefault true;
      config.common.default = lib.mkDefault "*";
    };

    systemd.services.flatpak-repo = lib.mkMerge [
      {
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.flatpak ];
        script = ''
          flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        '';
      }
      cfg.unitOverrides
    ];
  };
}
