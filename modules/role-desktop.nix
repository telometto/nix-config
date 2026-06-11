{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.role.desktop;
  THEME = "loader";
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

      ## Pull specific packages from different nixpkgs inputs
      overlays = {
        # fromInputs = {
        #   nixpkgs = [
        #     "pipx"
        #     "openrazer"
        #   ];
        # nixpkgs-beta = [];
        #   nixpkgs-unstable = [ "vscode" ];
        # nixpkgs-small = [];
        # };

        ## Add custom overlays
        custom = [
          (final: prev: {
            # openldap = prev.openldap.overrideAttrs {
            #   doCheck = !prev.stdenv.hostPlatform.isi686; # temporary fix for 513245
            # };

            pipx = prev.pipx.overrideAttrs {
              # Issues on master
              doInstallCheck = false;
            };
          })
        ];
      };
    };

    sys.home.enable = true;

    networking.firewall.enable = true;
  };
}
