{ config, lib, pkgs, myVars, ... }:

{
  home = {
    username = myVars.mainUsers.server.user;
    stateVersion = "24.05";

    packages = with pkgs; [
      # Your packages here
      atuin
      bash
      bat
      #blesh
      direnv
      eza
      fzf
      nix-direnv
      sqlite
      zoxide
    ];
  };

  programs = {
    home-manager = {
      enable = true;
    };

    atuin = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      #settings = {
      # key_path = "/opt/sec/atuin-file"
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

    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
  };
}
