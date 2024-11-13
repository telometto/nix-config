{ config, lib, pkgs, myVars, ... }:

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

    git = {
      enable = true;

      diff-so-fancy = {
        enable = true;
      };
    };

    gpg = {
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

    ssh = {
      enable = true;

      addKeysToAgent = "yes";
      #controlMaster = "auto";
      #controlPath = "/some/path/%r@%h:%p";
      #controlPersist = "yes";
      compression = true;
      #extraConfig = ""; # Strings concatenated with "\n"
      #extraOptionOverrides = ""; # Attribute set of strings
      forwardAgent = true;
      #hashKnownHosts = true;
      #includes = [ ]; # List of strings
      #matchBlocks = { }; # Attribute set of attribute sets
      #serverAliveCountMax = 1; # Positive integer
      #serverAliveInterval = 1;
      #userKnownHostsFile = ""; # String
    };

    tmux = {
      enable = true;
      clock24 = true;
      mouse = false;

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
