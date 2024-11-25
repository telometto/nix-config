{ config, lib, pkgs, myVars, ... }:

{
  imports = [
    ../../../security/secrets/sops-home.nix

    ./programs.nix
    ./services.nix
  ];

  programs.home-manager.enable = true;

  home = {
    username = myVars.users.admin.user;
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
