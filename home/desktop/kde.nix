{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.desktop.kde;
in
{
  options.hm.desktop.kde = {
    enable = lib.mkEnableOption "KDE Plasma desktop environment configuration";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional KDE packages to install";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional KDE configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkDefault (
      [
        pkgs.kdePackages.kate
        pkgs.kdePackages.kdeconnect-kde
        pkgs.kdePackages.kcalc
        pkgs.kdePackages.kolourpaint
      ]
      ++ cfg.extraPackages
    );

    xdg = {
      mimeApps = {
        enable = lib.mkDefault true;
        defaultApplications = lib.mkDefault {
          "image/*" = [ "org.nomacs.ImageLounge.desktop" ];
        };
      };
    };
  };
}
