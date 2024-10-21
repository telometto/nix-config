{ config, lib, pkgs, myVars, ... }:

{
  imports = [ ./programs.nix ]
    ++ lib.optional myVars.general.enableGnome ./gnome.nix
    ++ lib.optional myVars.general.enableKDE ./kde.nix;

  home = {
    username = myVars.laptop.user;
    stateVersion = "24.05";

    packages = with pkgs; [
      # Your packages here
      atuin
      bash
      bat
      #blesh
      direnv
      eza
      #firefox
      fzf
      nix-direnv
      sqlite
      zoxide

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
