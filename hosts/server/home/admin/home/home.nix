{ config, lib, pkgs, VARS, ... }:

{
  imports = [
    ../../../../../common/security/secrets/sops-home.nix

    ./programs.nix
    ./services.nix
  ];

  programs.home-manager.enable = true;

  home = {
    username = VARS.users.admin.user; # Change this back upon reformatting
    stateVersion = "24.11";

    packages = with pkgs; [
      # Your packages here
      atuin
      #blesh
      sqlite
      zsh-powerlevel10k
    ];
  };
}
