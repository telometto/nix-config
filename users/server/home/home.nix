{ config, lib, pkgs, myVars, ... }:

{
  imports = [ ./programs.nix ];

  home = {
    username = myVars.mainUsers.server.user;
    stateVersion = "24.05";

    packages = with pkgs; [
      # Your packages here
      atuin
      #blesh
      sqlite
    ];
  };

  programs.home-manager.enable = true;
}
