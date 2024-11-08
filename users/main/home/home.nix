{ config, lib, pkgs, myVars, ... }:

{
  imports = [
    ./kde.nix

    ./programs.nix
    ./services.nix
    ./xdg.nix
  ];
  # ++ lib.optional myVars.general.enableGnome ./gnome.nix
  # ++ lib.optional myVars.general.enableKDE ./kde.nix;

  home = {
    username = myVars.mainUsers.desktop.user;
    stateVersion = "24.05";

    packages = with pkgs; [
      # Utils
      atuin
      #blesh
      #deja-dup
      gparted
      meld
      polychromatic
      variety

      # Gaming
      steam
      #mangohud

      # Media
      texlivePackages.scheme-full
      mpv

      # Internet
      brave
      protonmail-desktop
      thunderbird

      # Social
      discord
      element-desktop

      # VS Code
      nixd # Nix language server for VS Code
      nixpkgs-fmt # Nix language formatter
      (vscode-with-extensions.override {
        vscodeExtensions = with vscode-extensions; [
          jnoortheen.nix-ide
          pkief.material-icon-theme
          github.copilot
        ];
      })
    ];
  };

  programs.home-manager.enable = true;
}
