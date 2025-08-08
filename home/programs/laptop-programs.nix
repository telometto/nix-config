# Laptop-specific program configurations
{ config, lib, pkgs, VARS, ... }:

let LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
in {
  programs = {
    # Laptop-specific programs like power management tools, battery indicators, etc.
    # This can be expanded as needed

    # Example: laptop-specific browser config with power-saving settings
    firefox = {
      enable = false;
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

    # Other laptop-specific configurations...
    mangohud = { enable = true; };

    mpv = {
      enable = true;
      # Consider creating a proper mpv.nix module with declarative configuration
    };

    vesktop = {
      enable = true;
      vencord = {
        useSystem = true;
        # Note: themes are only available on desktop configuration
      };
    };

    zellij = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      # Consider setting up declarative Zellij layouts and keybindings
    };
  };
}
