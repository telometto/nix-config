# Avalanche Laptop Home Manager configuration for admin user
{ config, lib, pkgs, VARS, inputs, ... }:

{
  imports = [
    ../../../../../shared/home.nix
    ../../../../../home/secrets.nix
    ../../../../../home/programs/laptop-programs.nix
    ../../../../../home/services/laptop-services.nix
  ];

  home = {
    username = VARS.users.admin.user;
    stateVersion = "24.05";

    enableDebugInfo = true;
    preferXdgDirectories = true;

    keyboard.layout = "no";

    # Localization
    language = {
      address = "nb_NO.UTF-8";
      base = "en_US.UTF-8";
      collate = "nb_NO.UTF-8";
      ctype = "nb_NO.UTF-8";
      measurement = "nb_NO.UTF-8";
      messages = "nb_NO.UTF-8";
      monetary = "nb_NO.UTF-8";
      name = "nb_NO.UTF-8";
      numeric = "nb_NO.UTF-8";
      paper = "nb_NO.UTF-8";
      telephone = "nb_NO.UTF-8";
      time = "nb_NO.UTF-8";
    };
  };

  # Laptop-specific packages
  home.packages = with pkgs; [
    # Utils
    atuin # History manager
    variety # Wallpaper changer
    zsh-powerlevel10k

    # Media
    jamesdsp
    mpv # Media player

    # Internet
    brave # Web browser
    thunderbird # Email client
    yt-dlp # YouTube downloader

    # Social
    discord # Discord client
    element-desktop # Matrix client

    # Development
    nixd # Nix language server for VS Code
    nixpkgs-fmt # Nix language formatter

    # Misc
    yaru-theme # Yaru theme for Ubuntu
    spotify # Music streaming
    pdfmixtool
  ];

  # Laptop-specific programs
  programs = {
    mangohud = { enable = true; };

    mpv = { enable = true; };
  };

  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;
}
