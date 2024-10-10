{ config, lib, pkgs, ... }:
let
  vars = import ../../vars/vars.nix;
in
{
  home = {
    username = "${vars.serverUser}";
    homeDirectory = "/home/${vars.serverUser}";
    stateVersion = "24.05";

    packages = with pkgs; [
      # Your packages here
      #atuin
      #bash
      #bat
      #blesh
      #eza
      #fzf
      #git
      #gnupg
      #zoxide
      sqlite
    ];  
  };

  programs = {
    home-manager = {
      enable = true;
    };

    atuin ={
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
      #completion.enable = true;
    };

    bat = {
      enable = true;
    };

    eza = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      
      git = true;
      icons = true;

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

    #gnupg = {
    #  agent = {
    #   enable = true;
    #   enableSSHSupport = true;
    #  };
    #};

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

    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
  };
}