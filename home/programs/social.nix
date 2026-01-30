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

        vencord = {
          useSystem = lib.mkDefault false;

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

            plugins = {
              FakeNitro.enabled = true;
              ClearURLs.enabled = true;
              DisableDeepLinks.enabled = true;
              ExpressionCloner.enabled = true;
              MessageLogger.enabled = true;
              TypingIndicator.enabled = true;
              Summaries.enabled = true;
              ShowHiddenChannels.enabled = true;
            };
          };
        };
      };
    };

    home.packages = [ ];
  };
}
