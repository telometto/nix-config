# Snowfall Desktop Home Manager configuration for admin user
{ config, lib, pkgs, VARS, inputs, ... }:

{
  home = {
    username = VARS.users.admin.user;
    stateVersion = "24.05";

    enableDebugInfo = true;
    preferXdgDirectories = true;

    keyboard.layout = "no";
  };

  imports = [
    inputs.nix-colors.homeManagerModules.default

    ../../../../../shared/home.nix
    ../../../../../home/secrets.nix
    ../../../../../home/programs/desktop-programs.nix
    ../../../../../home/services/desktop-services.nix
  ];

  # KDE Desktop Environment packages
  home.packages = with pkgs; [
    # KDE applications
    kdePackages.kate
    kdePackages.kdeconnect-kde
    kdePackages.kcalc
    kdePackages.kolourpaint

    # Development
    vscode
    jetbrains.idea-ultimate

    # Media and graphics
    #gimp inkscape blender
    obs-studio # kdenlive

    # Communication
    #discord slack teams

    # Gaming
    # steam
    # lutris
    # heroic

    # System monitoring
    # nvtop
  ];

  # Desktop-specific localization
  home.language = {
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

  # KDE-specific services
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;
}
