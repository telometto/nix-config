{ lib, config, ... }:
let
  cfg = config.hm.programs.social;
in
{
  options.hm.programs.social = {
    enable = lib.mkEnableOption "Gaming tools and configuration";

    vesktop.enable = lib.mkEnableOption "Vesktop (Discord clone)";
    element-desktop.enable = lib.mkEnableOption "Element";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      element-desktop.enable = lib.mkDefault cfg.element-desktop.enable;

      vesktop = lib.mkIf cfg.vesktop.enable {
        enable = lib.mkDefault true;

        # settings = {};

        # FIXME: useSystem causes patch failure in Vesktop 1.6.0
        # Re-enable when nixpkgs patches are updated
        # See: https://github.com/NixOS/nixpkgs/issues/vesktop-use-system-vencord
        vencord = {
          useSystem = lib.mkDefault true;

          themes = {
            clearvision = ../files/vesktop-themes/ClearVision-v7-BetterDiscord.theme.css;
            glass = ../files/vesktop-themes/glass_local.theme.css;
          };

          settings = {
            useQuickCss = true;
            enabledThemes = [
              "clearvision.css"
              "glass.css"
            ];
          };
        };
      };
    };

    home.packages = [ ];
  };
}
