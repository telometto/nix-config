{ config, lib, pkgs, myVars, ... }:
let
  LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
in
{
  programs = {
    atuin = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      #settings = {
      #  key_path = "/opt/sec/atuin-file";
      #};
    };

    bash = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true; # Enable VTE integration to track current directory
      historyControl = [ "erasedups" ]; # Remove duplicates in history
    };

    bat = {
      enable = true;
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      nix-direnv.enable = true;
    };

    eza = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      git = true;
      icons = "always";

      extraOptions = [
        "--group-directories-first"
        "--header"
        "--long"
      ];
    };

    fzf = {
      enable = true;

      tmux.enableShellIntegration = true;
    };

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

    git = {
      enable = true;

      userName = "telometto";
      userEmail = "65364211+telometto@users.noreply.github.com";

      signing = {
        signByDefault = true;
        key = "0x5A5BF29378C3942B";
      };

      diff-so-fancy = {
        enable = true;
      };
    };

    gpg = {
      enable = true;
    };

    mangohud = {
      enable = true;
    };

    micro = {
      enable = true;

      settings = {
        autosu = true;
        mkparents = true;
        colorscheme = "gruvbox-tc";
        hlsearch = true;
        hltaberrors = true;
        tabtospaces = true;
      };
    };

    mpv = {
      enable = true;

      # TODO: Declaratively configure mpv
    };

    /*
      thunderbird = {
      enable = true;

      # TODO: Declaratively configure Thunderbird
      };
    */

    tmux = {
      enable = true;
      clock24 = true;
      mouse = true;

      #plugins = {
      #  dracula = {
      #    enable = true;
      #  };
      #
      #  gruvbox = {
      #    enable = true;
      #  };
      #};
    };

    /*
      vscode = {
      enable = true;

      enableUpdateCheck = false; # Disable update checks
      mutableExtensionsDir = true; # Allow extensions to be installed in the user's home directory

      # TODO: Declaratively configure Visual Studio Code
      };
    */

    zellij = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      # TODO: Declaratively configure Zellij
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    zsh = {
      enable = true;

      enableCompletion = true;
      autosuggestion = { enable = true; };
      syntaxHighlighting = { enable = true; };
      autocd = true;
      enableVteIntegration = true;

      history = {
        expireDuplicatesFirst = true;
        extended = true;
        ignoreAllDups = true;
      };

      initExtraBeforeCompInit = ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      '';

      initExtra = ''
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      '';

      oh-my-zsh = {
        enable = true;

        #theme = "powerlevel10k";

        plugins = [
          #"autoenv"
          "colorize"
          "command-not-found"
          "common-aliases"
          "copybuffer"
          "git"
          "sudo"
          "podman"
          "systemd"
          "tailscale"
          "tmux"
          "vscode"
          #"zsh-autosuggestions"
          #"zsh-syntax-highlighting"
        ];
      };
    };

  };
}
