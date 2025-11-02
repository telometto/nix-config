{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.programs.browsers;

  LANGUAGES = [
    "nb-NO"
    "it-IT"
    "en-US"
  ];
in
{
  options.hm.programs.browsers = {
    enable = lib.mkEnableOption "Web browsers configuration";

    firefox.enable = lib.mkEnableOption "Firefox browser";
    floorp.enable = lib.mkEnableOption "Floorp browser";
    chromium.enable = lib.mkEnableOption "Chromium browser policies";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      firefox = lib.mkIf cfg.firefox.enable {
        enable = lib.mkDefault true;

        languagePacks = LANGUAGES;

        policies = {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          DisablePocket = true;
          DisableFirefoxAccounts = false;
          OverrideFirstRunPage = "";
          OverridePostUpdatePage = "";
          DontCheckDefaultBrowser = true;
          DisplayBookmarksToolbar = "always";
          DisplayMenuBar = "default-off";
          SearchBar = "unified";

          EnableTrackingProtection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };
        };
      };

      floorp = lib.mkIf cfg.floorp.enable {
        enable = lib.mkDefault true;

        policies = {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          DisablePocket = true;
          DisableFirefoxAccounts = false;
          DontCheckDefaultBrowser = true;
          DisplayBookmarksToolbar = "always";
          DisplayMenuBar = "default-off";
          SearchBar = "unified";

          EnableTrackingProtection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };
        };
      };

      chromium = lib.mkIf cfg.chromium.enable { enable = lib.mkDefault true; };
    };

    home.packages = [
      pkgs.brave
    ];
  };
}
