{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.role.desktop;
in
{
  config = lib.mkIf cfg.enable {
    telometto = {
      boot = {
        lanzaboote.enable = true;
        plymouth = {
          enable = true;
          theme = "cuts";
          themePackages = [
            (pkgs.adi1090x-plymouth-themes.override {
              selected_themes = [ "cuts" ];
            })
          ];
        };
      };

      networking = {
        base.enable = true;
        networkmanager.enable = true;
      };

      programs = {
        gaming.enable = true;
        java.enable = true;
        ssh.enable = false;
        gnupg.enable = false;
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

    telometto.home.enable = true;

    networking.firewall.enable = true;
  };
}
