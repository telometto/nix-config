{ config, lib, pkgs, myVars, ... }:

{
  imports = [ ./programs.nix ]
    ++ lib.optional myVars.general.enableGnome ./gnome.nix
    ++ lib.optional myVars.general.enableKDE ./kde.nix;

  home = {
    username = myVars.extraUsers.wife.user;
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
    ];
  };

  programs.home-manager.enable = true;
}
