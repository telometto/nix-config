{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.role.desktop;
  THEME = "dna";
in
{
  config = lib.mkIf cfg.enable {
    sys = {
      boot = {
        lanzaboote.enable = true;
        plymouth = {
          enable = true;
          theme = THEME;
          themePackages = [
            (pkgs.adi1090x-plymouth-themes.override {
              selected_themes = [ THEME ];
            })
          ];
        };
      };

      networking = {
        base.enable = true;
        networkmanager.enable = true;
      };

      programs = {
        java.enable = true;
        ssh.enable = true;
        gnupg.enable = false;

        gaming = {
          enable = true;

          steam.enable = true;
        };
      };

      services = {
        openssh = {
          enable = true;
          openFirewall = true;
        };

        timesyncd.enable = true;
        resolved.enable = true;
        maintenance.enable = true;
        autoUpgrade.enable = false;
        pipewire.enable = true;
        printing.enable = true;
        flatpak.enable = true;
        tailscale.enable = true;
      };

      virtualisation.enable = true;
    };

    sys.home.enable = true;

    networking.firewall.enable = true;
  };
}
