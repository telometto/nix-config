{ config, lib, pkgs, VARS, ... }:
let
  LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
in
{
  programs = {
    firefox = {
      enable = true;

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

    floorp = {
      enable = true;

      #languagePacks = [ "nb-NO" "it-IT" "en-US" ];
    };

    mangohud = { enable = true; };

    mpv = { enable = true; };

    zellij = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

  };
}