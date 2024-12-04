{ config, lib, pkgs, VARS, ... }:

{
  imports = [
    ../../../security/secrets/sops-home.nix

    ./programs.nix
    ./services.nix
  ];

  programs.home-manager.enable = true;

  home = {
    username = VARS.users.serverAdmin.user; # Change this back upon reformatting
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
