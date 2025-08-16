{ config, lib, pkgs, VARS, ... }:
let
  LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
in
{
  programs = {
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
        # OverrideFirstRunPage = "";
        # OverridePostUpdatePage = "";
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

    mangohud = {
      enable = true;

      settings = {
        # time = true;
        # time_no_label = true;
        # time_format = "%T";

        gpu_stats = true;
        gpu_temp = true;
        gpu_text = "GPU";
        gpu_load_change = true;
        gpu_load_color = "39F900,FDFD09,B22222";

        cpu_stats = true;
        cpu_temp = true;
        cpu_text = "CPU";
        cpu_load_change = true;
        cpu_load_color = "39F900,FDFD09,B22222";

        vram = true;
        ram = true;

        fps = true;
        fps_color_change = true;
        fps_color = "B22222,FDFD09,39F900";
        frametime = true;

        throttling_status = true;
        frame_timing = true;
        gamemode = true;

        media_player = true;
        media_player_name = "spotify";
        media_player_format = "title,artist,album";

        text_outline = true;
      };
    };

    mpv = { enable = true; };

    zellij = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

  };
}
