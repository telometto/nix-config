{ config, lib, pkgs, myVars, ... }:

{
  imports = [
    ./programs.nix
  ];

  home = {
    username = myVars.users.luke.user;
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
      plasma5Packages.kdeconnect-kde
      nix-direnv
      sqlite
      zoxide
    ];
  };

  programs.home-manager.enable = true;
}
