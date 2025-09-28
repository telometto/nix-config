{ lib, config, pkgs, VARS, ... }:
let cfg = config.hm.desktop.kde;
in {
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
    home.packages = [
      # Core KDE applications
      pkgs.kdePackages.kate
      pkgs.kdePackages.kdeconnect-kde
      pkgs.kdePackages.kcalc
      pkgs.kdePackages.kolourpaint
    ] ++ cfg.extraPackages;

    # Qt configuration - can be extended via qtConfig option
    # qt = lib.mkMerge [
    #   {
    #     enable = true;
    #     platformTheme.name = "kde";
    #     style.name = "breeze";
    #   }
    #   cfg.qtConfig
    # ];

    # XDG MIME associations from old config
    xdg = {
      # configFile = {
      #  "Kvantum/ArcDark".source = "${pkgs.arc-kde-theme}/share/Kvantum/ArcDark";
      #  "Kvantum/kvantum.kvconfig".text = "[General]\ntheme=ArcDark";
      #};
      mimeApps = {
        enable = true;
        defaultApplications = {
          "image/*" = [ "org.nomacs.ImageLounge.desktop" ];
        };
      };
    };
  };
}
