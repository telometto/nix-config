{ config, lib, pkgs, VARS, ... }:
let
  DEFAULT_LANG = "it_IT.UTF-8";
in
{
  imports = [
    # Common imports
    ../../../../../common/home/imports.nix

    # Desktop environments
    # ../../../../../common/home/desktop-environments/gnome/defaults.nix # Enables GNOME
    ../../../../../common/home/desktop-environments/hyprland/defaults.nix # Enables Hyprland
    ../../../../../common/home/desktop-environments/kde/defaults.nix # Enables KDE

    # User-specific imports
    ./programs/programs.nix
  ];

  users.extraUsers.${VARS.users.luke.user} = {
    description = VARS.users.luke.description;
    isNormalUser = VARS.users.luke.isNormalUser;
    extraGroups = VARS.users.luke.extraGroups;
    hashedPassword = VARS.users.luke.hashedPassword;
    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };

  programs.home-manager.enable = true; # Enable home-manager

  home = {
    username = VARS.users.luke.user;
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
