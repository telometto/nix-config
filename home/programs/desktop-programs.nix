{ config, lib, pkgs, VARS, ... }:

let LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
in {
  programs = {
    fastfetch = {
      settings = {
        modules = [
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
      };
    };

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

    ghostty = {
      enable = true;

      enableBashIntegration = true;
      enableZshIntegration = true;

      settings = { theme = "catppuccin-frappe"; };
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

    mpv = {
      enable = true;

      # Consider creating a proper mpv.nix module with declarative configuration
    };

    # SSH is on hold until config permissions are fixed; see https://github.com/nix-community/home-manager/issues/322

    # ssh = {
    #   enable = false;

    # extraConfig = ''
    #   AddKeysToAgent yes

    #   Host github.com
    #     Hostname ssh.github.com
    #     Port 443

    #   Host 192.168.*
    #     ForwardAgent yes
    #     IdentityFile /home/zeno/.ssh/id_ed25519
    #     IdentitiesOnly yes
    #     SetEnv TERM=xterm-256color
    # '';

    # addKeysToAgent = "yes";
    # # controlMaster = "auto";
    # # controlPath = "/some/path/%r@%h:%p";
    # # controlPersist = "yes";
    # compression = true;
    # # extraConfig = ""; # Strings concatenated with "\n"
    # # extraOptionOverrides = ""; # Attribute set of strings
    # forwardAgent = true;
    # # hashKnownHosts = true;
    # # includes = [ ]; # List of strings
    # # matchBlocks = { }; # Attribute set of attribute sets
    # # serverAliveCountMax = 1; # Positive integer
    # # serverAliveInterval = 1;
    # # userKnownHostsFile = ""; # String
    # };

    /* thunderbird = {
       enable = true;

       # Consider setting up declarative Thunderbird profiles and settings
       };
    */

    vesktop = {
      enable = true;

      # settings = {};

      vencord = {
        useSystem = true;

        themes = {
          clearvision = ./vesktop-themes/ClearVision-v7-BetterDiscord.theme.css;
          glass = ./vesktop-themes/glass_local.theme.css;
        };

        settings = {
          useQuickCss = true;
          enabledThemes = [ "clearvision.css" "glass.css" ];
        };
      };
    };

    /* vscode = {
       enable = true;

       enableUpdateCheck = false; # Disable update checks
       mutableExtensionsDir = true; # Allow extensions to be installed in the user's home directory

       # Consider setting up declarative VS Code extensions and settings
       };
    */

    zellij = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      # Consider setting up declarative Zellij layouts and keybindings
      # settings = {
      #   theme = "gruvbox-dark";
      # };
    };

    alacritty = {
      enable = true;

      settings = {
        colors = with config.colorScheme.palette; {
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

  };
}
