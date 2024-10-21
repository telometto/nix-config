{ config, lib, pkgs, myVars, ... }:

{
  imports = [ ./programs.nix ];

  home = {
    username = myVars.mainUsers.server.user;
    stateVersion = "24.05";

    packages = with pkgs; [
      # Your packages here
      atuin
      bash
      bat
      #blesh
      direnv
      eza
      fzf
      nix-direnv
      sqlite
      zoxide
    ];
  };

  programs.home-manager.enable = true;
}
