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
        lanzaboote.enable = lib.mkDefault true;
        plymouth = {
          enable = lib.mkDefault true;
          theme = "lone";
          themePackages = [
            (pkgs.adi1090x-plymouth-themes.override {
              selected_themes = [ "lone" ];
            })
          ];
        };
      };

      networking = {
        base.enable = lib.mkDefault true;
        networkmanager.enable = lib.mkDefault true;
      };

      programs = {
        gaming.enable = lib.mkDefault true;
        java.enable = lib.mkDefault true;
        # SSH and GPG managed per-user via home-manager by default
        ssh.enable = lib.mkDefault false;
        gnupg.enable = lib.mkDefault false;
      };

      services = {
        openssh = {
          enable = lib.mkDefault true;
          openFirewall = lib.mkDefault true;
        };
        timesyncd.enable = lib.mkDefault true;
        resolved.enable = lib.mkDefault true;
        maintenance.enable = lib.mkDefault true;
        autoUpgrade.enable = lib.mkDefault false;
        pipewire.enable = lib.mkDefault true;
        printing.enable = lib.mkDefault true;
        flatpak.enable = lib.mkDefault true;
        tailscale.enable = lib.mkDefault true;
      };

      virtualisation.enable = lib.mkDefault true;
    };

    # Enable home-manager for desktop users
    telometto.home.enable = lib.mkDefault true;

    # Enable firewall with restrictive defaults (deny all by default)
    networking.firewall.enable = lib.mkDefault true;
  };
}
