{ config, lib, inputs, pkgs, VARS, pkgs-stable, pkgs-unstable, ... }:
let
  DEFAULT_LANG = "nb_NO.UTF-8";
in
{
  imports = [
    inputs.nix-colors.homeManagerModules.default

    # Common imports
    ../../../../../common/home/imports.nix

    # Secrets
    ../../../../../common/home/security/secrets/sops-home.nix

    # Desktop environments
    # ../../../../../common/home/desktop-environments/gnome/defaults.nix # Enables GNOME
    # ../../../../../common/home/desktop-environments/hyprland/defaults.nix # Enables Hyprland
    ../../../../../common/home/desktop-environments/kde/defaults.nix # Enables KDE

    # User-specific imports
    ./programs/programs.nix
    ./services/gpg/agent.nix
    # ./xdg/xdg.nix
  ];

  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

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

    packages = [
      # Utils
      # pkgs.atuin # History manager
      # pkgs.blesh
      pkgs.gparted # Partition manager
      pkgs.meld # Diff tool
      pkgs-unstable.variety # Wallpaper changer
      pkgs.zsh-powerlevel10k
      pkgs.polychromatic # Razer configuration tool
      # pkgs.ghostty
      pkgs.flameshot
      # pkgs.rustdesk
      # pkgs.teamviewer
      pkgs.czkawka # Duplicate file finder
      pkgs.ansible
      pkgs.figma-linux

      # Gaming
      # pkgs.mangohud

      # Media
      pkgs.jamesdsp
      # pkgs.mpv # Media player

      # Internet
      pkgs.brave # Web browser
      pkgs.protonmail-desktop # ProtonMail client
      pkgs.thunderbird # Email client
      pkgs.yt-dlp # YouTube downloader
      pkgs.protonvpn-gui # ProtonVPN GUI client
      pkgs.plex-desktop # Plex media player for desktop

      # Social
      pkgs.discord # Discord client
      pkgs.element-desktop # Matrix client
      pkgs.teams-for-linux # Microsoft Teams client
      # pkgs.weechat # IRC client
      pkgs.zoom-us # Zoom client

      # Development
      pkgs.nixd # Nix language server for VS Code
      pkgs.nixpkgs-fmt # Nix language formatter
      pkgs.nixfmt-classic # Nix language formatter
      pkgs.vscode # Visual Studio Code
      pkgs.jetbrains.idea-community-bin # IntelliJ IDEA Community Edition

      pkgs.texliveFull # LaTeX

      # Misc
      pkgs.fortune # Random quotes
      pkgs.yaru-theme # Yaru theme for Ubuntu
      pkgs.spotify # Music streaming
      pkgs.pdfmixtool # PDF tool
      pkgs.onlyoffice-desktopeditors # Office suite
      pkgs.nomacs # Image viewer
      pkgs.apostrophe # Markdown editor
      pkgs.gpt4all

      # System tools
      # deja-dup # Backup tool; use Flatpak instead
      # restic # Does not enable restic in deja-dup
      pkgs.vorta # Backup software

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
