{ config, lib, pkgs, myVars, ... }:
let
  DEFAULT_LANG = "nb_NO.UTF-8";
in
{
  imports = [
    ./gnome.nix # Enables GNOME
    # ./hyprland.nix # Enables Hyprland
    # ./kde.nix # Enables KDE

    # ../../../security/secrets/sops-home.nix

    ./programs.nix
    ./services.nix
    ./xdg.nix
  ];

  programs.home-manager.enable = true; # Enable home-manager

  home = {
    username = myVars.users.wife.user;
    stateVersion = "24.05";

    # Localization
    language = {
      address = DEFAULT_LANG;
      base = DEFAULT_LANG;
      collate = DEFAULT_LANG;
      ctype = DEFAULT_LANG;
      measurement = DEFAULT_LANG;
      messages = DEFAULT_LANG;
      monetary = DEFAULT_LANG;
      name = DEFAULT_LANG;
      numeric = DEFAULT_LANG;
      paper = DEFAULT_LANG;
      telephone = DEFAULT_LANG;
      time = DEFAULT_LANG;
    };
    keyboard = {
      layout = "no";
      # variant = "";
    };

    packages = with pkgs; [
      # Utils
      atuin # History manager
      #blesh
      variety # Wallpaper changer
      zsh-powerlevel10k

      # Gaming
      #mangohud

      # Media
      jamesdsp
      #mpv # Media player

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

      # System tools
      # deja-dup # Backup tool; use Flatpak instead
      # restic # Does not enable restic in deja-dup
      # vorta # Backup software
    ];
  };
}
