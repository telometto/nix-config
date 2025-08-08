# Common home package definitions to reduce duplication
{ config, lib, pkgs, VARS, ... }:

let mylib = import ../lib { inherit lib VARS; };
in {
  # Common user packages across all devices
  base = [
    # Essential utilities
    # pkgs.atuin # History manager
    # pkgs.blesh
    pkgs.zsh-powerlevel10k
    pkgs.ansible
    pkgs.yt-dlp # YouTube downloader
    pkgs.nixd # Nix language server for VS Code
    pkgs.nixpkgs-fmt # Nix language formatter
    pkgs.nixfmt-classic # Nix language formatter
  ];

  # Laptop specific packages
  laptop = [
    # Utils
    pkgs.gparted # Partition manager
    pkgs.meld # Diff tool
    pkgs.variety # Wallpaper changer
    # pkgs.polychromatic # Razer configuration tool
    pkgs.flameshot

    # Media
    pkgs.jamesdsp

    # Internet
    pkgs.brave # Web browser
    pkgs.protonmail-desktop # ProtonMail client
    pkgs.thunderbird # Email client
    # pkgs.protonvpn-gui # ProtonVPN GUI client

    # Social
    pkgs.element-desktop # Matrix client
    # pkgs.teams-for-linux # Microsoft Teams client
    # pkgs.weechat # IRC client

    # Development
    pkgs.vscode # Visual Studio Code
    pkgs.jetbrains.idea-community-bin # IntelliJ IDEA Community Edition

    # pkgs.texliveFull # LaTeX

    # Misc
    pkgs.fortune # Random quotes
    pkgs.yaru-theme # Yaru theme for Ubuntu
    pkgs.spotify # Music streaming
    pkgs.pdfmixtool # PDF tool
    pkgs.onlyoffice-desktopeditors # Office suite
    pkgs.nomacs

    # System tools
    # pkgs.deja-dup # Backup tool; use Flatpak instead
    # pkgs.restic # Does not enable restic in deja-dup
    pkgs.vorta # Backup software
  ];

  # Desktop specific packages
  desktop = [
    # Utils
    pkgs.gparted # Partition manager
    pkgs.meld # Diff tool
    pkgs.variety # Wallpaper changer
    pkgs.polychromatic # Razer configuration tool
    pkgs.flameshot
    # pkgs.rustdesk
    pkgs.czkawka # Duplicate file finder
    pkgs.figma-linux

    # Media
    pkgs.jamesdsp

    # Internet
    pkgs.brave # Web browser
    pkgs.protonmail-desktop # ProtonMail client
    pkgs.thunderbird # Email client
    pkgs.protonvpn-gui # ProtonVPN GUI client
    # pkgs.plex-desktop # Plex media player for desktop

    # Social
    pkgs.element-desktop # Matrix client
    pkgs.teams-for-linux # Microsoft Teams client
    # pkgs.weechat # IRC client
    pkgs.zoom-us # Zoom client

    # Development
    pkgs.vscode # Visual Studio Code
    # pkgs.jetbrains.idea-community-bin # IntelliJ IDEA Community Edition

    # pkgs.texliveFull # LaTeX

    # Misc
    # pkgs.fortune # Random quotes
    pkgs.yaru-theme # Yaru theme for Ubuntu
    pkgs.spotify # Music streaming
    pkgs.pdfmixtool # PDF tool
    pkgs.onlyoffice-desktopeditors # Office suite
    pkgs.nomacs # Image viewer
    # pkgs.apostrophe # Markdown editor
    pkgs.gpt4all
    pkgs.tuxguitar
    pkgs.pgadmin4-desktopmode

    # System tools
    # deja-dup # Backup tool; use Flatpak instead
    # restic # Does not enable restic in deja-dup
    pkgs.vorta # Backup software

    ## Declaratively configure VS Code with extensions
    ## NOTE: Settings will not be synced
    # (pkgs.vscode-with-extensions.override {
    #  vscodeExtensions = with vscode-extensions; [
    #    jnoortheen.nix-ide
    #    pkief.material-icon-theme
    #    github.copilot
    #  ];
    # })
  ];

  # Server packages (minimal)
  server = [
    # Your packages here
    pkgs.sqlite
    pkgs.zsh-powerlevel10k
  ];
}
