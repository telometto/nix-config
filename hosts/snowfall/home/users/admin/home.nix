{ config, lib, pkgs, VARS, pkgs-stable, ... }:
let
  DEFAULT_LANG = "nb_NO.UTF-8";
in
{
  imports = [
    # Common imports
    ../../../../../common/home/imports.nix

    # Secrets
    ../../../../../common/home/security/secrets/sops-home.nix

    # Desktop environments
    # ../../../../../common/home/desktop-environments/gnome/defaults.nix # Enables GNOME
    ../../../../../common/home/desktop-environments/hyprland/defaults.nix # Enables Hyprland
    ../../../../../common/home/desktop-environments/kde/defaults.nix # Enables KDE

    # User-specific imports
    ./programs/programs.nix
    ./services/gpg/agent.nix
    # ./xdg/xdg.nix
  ];

  programs.home-manager.enable = true; # Enable home-manager

  home = {
    username = VARS.users.admin.user;
    stateVersion = "24.05";

    enableDebugInfo = true;
    preferXdgDirectories = true;

    # sessionPath = [
    #   # Extra paths; e.g. "/home/${config.home.username}/.local/bin"
    # ];

    # sessionVariables = {
    #   # Example: Set the default editor
    #   # EDITOR = "nvim";
    # };

    # shellAliases = {
    #   # Example: Add an alias for `ls`
    #   # ls = "ls --color=auto";
    # };

    # Localization
    # language = {
    #   address = DEFAULT_LANG;
    #   base = "en_US.UTF-8";
    #   collate = DEFAULT_LANG;
    #   ctype = DEFAULT_LANG;
    #   measurement = DEFAULT_LANG;
    #   messages = DEFAULT_LANG;
    #   monetary = DEFAULT_LANG;
    #   name = DEFAULT_LANG;
    #   numeric = DEFAULT_LANG;
    #   paper = DEFAULT_LANG;
    #   telephone = DEFAULT_LANG;
    #   time = DEFAULT_LANG;
    # };

    keyboard = {
      layout = "no";
      # variant = "";
    };

    packages = with pkgs; [
      # Utils
      atuin # History manager
      # blesh
      gparted # Partition manager
      meld # Diff tool
      variety # Wallpaper changer
      zsh-powerlevel10k
      polychromatic # Razer configuration tool

      # Gaming
      # mangohud

      # Media
      jamesdsp
      # mpv # Media player

      # Internet
      brave # Web browser
      protonmail-desktop # ProtonMail client
      thunderbird # Email client
      yt-dlp # YouTube downloader

      # Social
      discord # Discord client
      element-desktop # Matrix client
      teams-for-linux # Microsoft Teams client
      weechat # IRC client
      zoom-us # Zoom client

      # Development
      nixd # Nix language server for VS Code
      nixpkgs-fmt # Nix language formatter
      vscode # Visual Studio Code

      texliveFull # LaTeX

      # Misc
      fortune # Random quotes
      yaru-theme # Yaru theme for Ubuntu
      spotify # Music streaming
      pdfmixtool # PDF tool
      onlyoffice-desktopeditors # Office suite
      nomacs # Image viewer
      apostrophe # Markdown editor

      # System tools
      # deja-dup # Backup tool; use Flatpak instead
      # restic # Does not enable restic in deja-dup
      vorta # Backup software

      ## Declaratively configure VS Code with extensions
      ## NOTE: Settings will not be synced
      # (vscode-with-extensions.override {
      #  vscodeExtensions = with vscode-extensions; [
      #    jnoortheen.nix-ide
      #    pkief.material-icon-theme
      #    github.copilot
      #  ];
      # })
    ];
  };
}
