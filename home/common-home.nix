# Common home-manager configuration imported by all users
{ config, lib, pkgs, VARS, ... }:

{
  imports = [
    # Apply shared home configuration to all users
    ../shared/home.nix
  ];

  # Home Manager settings
  home = {
    username = VARS.USERNAME;
    homeDirectory = "/home/${VARS.USERNAME}";
    stateVersion = "24.11";
  };

  # Allow unfree packages in home-manager
  nixpkgs.config.allowUnfree = true;
}
