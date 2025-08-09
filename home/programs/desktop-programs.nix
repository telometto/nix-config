{ config, lib, pkgs, VARS, ... }:

let
  LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
  browserPolicies = {
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
  fastfetchModulesCommon = [
    "title"
    "separator"
    "os"
    "kernel"
    "initsystem"
    "uptime"
    "loadavg"
    "processes"
    "packages"
    "shell"
    "editor"
    "display"
    "de"
    "terminal"
    {
      "type" = "cpu";
      "showPeCoreCount" = true;
      "temp" = true;
    }
    "cpuusage"
    {
      "type" = "gpu";
      "driverSpecific" = true;
      "temp" = true;
    }
    "memory"
    "swap"
    "disk"
    { "type" = "localip"; }
    {
      "type" = "weather";
      "timeout" = 1000;
    }
    "break"
  ];
in
{
  programs = {
    fastfetch.settings.modules = fastfetchModulesCommon;

    firefox = {
      enable = false;
      languagePacks = LANGUAGES;
      policies = browserPolicies // {
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
      };
    };

    floorp = {
      enable = true;
      policies = browserPolicies;
    };

    ghostty = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      settings.theme = "catppuccin-frappe";
    };

    keychain = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      keys = [
        "id_ed25519"
        "gitlabkey"
        "deployment-keys"
        "nix-secrets"
        "testkey"
        "github-key"
      ];
    };

    mangohud = {
      enable = true;
      settings = {
        time = true;
        time_no_label = true;
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

    mpv.enable = true;

    vesktop = {
      enable = true;
      vencord = {
        useSystem = true;
        themes = {
          clearvision =
            ../vesktop-themes/ClearVision-v7-BetterDiscord.theme.css;
          glass = ../vesktop-themes/glass_local.theme.css;
        };
        settings = {
          useQuickCss = true;
          enabledThemes = [ "clearvision.css" "glass.css" ];
        };
      };
    };

    zellij = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    alacritty = {
      enable = true;
      settings.colors = with config.colorScheme.palette; {
        bright = {
          black = "0x${base00}";
          blue = "0x${base0D}";
          cyan = "0x${base0C}";
          green = "0x${base0B}";
          magenta = "0x${base0E}";
          red = "0x${base08}";
          white = "0x${base06}";
          yellow = "0x${base09}";
        };
        cursor = {
          cursor = "0x${base06}";
          text = "0x${base06}";
        };
        normal = {
          black = "0x${base00}";
          blue = "0x${base0D}";
          cyan = "0x${base0C}";
          green = "0x${base0B}";
          magenta = "0x${base0E}";
          red = "0x${base08}";
          white = "0x${base06}";
          yellow = "0x${base09}";
        };
        primary = {
          background = "0x${base00}";
          foreground = "0x${base06}";
        };
      };
    };
  };
}
