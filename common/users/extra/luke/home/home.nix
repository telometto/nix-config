{ config, lib, pkgs, myVars, ... }:

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
    username = myVars.users.luke.user;
    stateVersion = "24.05";

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
