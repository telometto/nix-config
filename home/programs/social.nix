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
          useSystem = lib.mkDefault false; # TODO: temporary until upstream fixes this

          settings = {
            # These wrappers import mutable remote CSS. Keep them disabled
            # until their complete stylesheet and asset closure is pinned.
            useQuickCss = false;
            enabledThemes = [ ];

            plugins = {
              ClearURLs.enabled = true;
              DisableDeepLinks.enabled = true;
              ExpressionCloner.enabled = true;
              FakeNitro.enabled = true;
              MessageLogger.enabled = true;
              NoTrack.enabled = true;
              ShowHiddenChannels.enabled = true;
              Summaries.enabled = true;
              TypingIndicator.enabled = true;
              WebScreenShare.enabled = true;
              WebScreenShareFixes.enabled = true;
            };
          };
        };
      };
    };

    home.packages = [ ];
  };
}
