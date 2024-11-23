{ config, lib, pkgs, myVars, ... }:

{
  imports = [
    ./programs.nix
    ./services.nix
  ];

  programs.home-manager.enable = true;

  home = {
    username = myVars.systems.server.adminUser.user;
    stateVersion = "24.05";

    packages = with pkgs; [
      # Your packages here
      atuin
      #blesh
      sqlite
      zsh-powerlevel10k
    ];
  };
}
