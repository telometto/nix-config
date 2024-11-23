{ config, lib, pkgs, myVars, ... }:

{
  imports = [
    # ./gnome.nix # Enables GNOME
    ./kde.nix # Enables KDE

    ../../../security/secrets/sops-home.nix

    ./programs.nix
    ./services.nix
    ./xdg.nix
  ];

  programs.home-manager.enable = true; # Enable home-manager

  home = {
    username = myVars.users.admin.user;
    stateVersion = "24.05";

    packages = with pkgs; [
      # Utils
      atuin # History manager
      #blesh
      gparted # Partition manager
      meld # Diff tool
      polychromatic # GUI for OpenRazer
      variety # Wallpaper changer
      zsh-powerlevel10k

      # Gaming
      #mangohud

      # Media
      jamesdsp
      #mpv # Media player

      # Internet
      brave # Web browser
      protonmail-desktop # ProtonMail client
      thunderbird # Email client

      # Social
      discord # Discord client
      element-desktop # Matrix client
      teams-for-linux # Microsoft Teams client

      # Development
      nixd # Nix language server for VS Code
      nixpkgs-fmt # Nix language formatter
      vscode # Visual Studio Code

      texliveFull # LaTeX

      # Misc
      fortune # Random quotes
      yaru-theme # Yaru theme for Ubuntu
      spotify # Music streaming
      pdfmixtool

      # System tools
      # deja-dup # Backup tool; use Flatpak instead
      # restic # Does not enable restic in deja-dup
      vorta # Backup software

      ## Declaratively configure VS Code with extensions
      ## NOTE: Settings will not be synced
      #(vscode-with-extensions.override {
      #  vscodeExtensions = with vscode-extensions; [
      #    jnoortheen.nix-ide
      #    pkief.material-icon-theme
      #    github.copilot
      #  ];
      #})
    ];
  };
}
