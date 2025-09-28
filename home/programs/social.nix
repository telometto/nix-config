{ lib, config, pkgs, VARS, ... }:
let cfg = config.hm.programs.social;
in {
  options.hm.programs.social = {
    enable = lib.mkEnableOption "Gaming tools and configuration";

    vesktop.enable = lib.mkEnableOption "Vesktop (Discord clone)";
    element-desktop.enable = lib.mkEnableOption "Element";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      element-desktop.enable = lib.mkIf cfg.element-desktop.enable { enable = true;};

      vesktop = lib.mkIf cfg.vesktop.enable {
        enable = true;

        # settings = {};

        vencord = {
          useSystem = true;

          themes = {
            clearvision =
              ../files/vesktop-themes/ClearVision-v7-BetterDiscord.theme.css;
            glass = ../files/vesktop-themes/glass_local.theme.css;
          };

          settings = {
            useQuickCss = true;
            enabledThemes = [ "clearvision.css" "glass.css" ];
          };
        };
      };
    };

    home.packages = [ ];
  };
}
