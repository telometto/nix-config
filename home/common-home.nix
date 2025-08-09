# Common home-manager configuration imported by all users
{ config, lib, pkgs, VARS, ... }:

{
  imports = [
    # Apply shared home configuration to all users
    ../shared/home.nix
  ];

  # The username & homeDirectory are already set in individual user modules; avoid using a non-existent VARS.USERNAME
  # Provide a fallback stateVersion only.
  home.stateVersion = lib.mkDefault "24.11";

  nixpkgs.config.allowUnfree = true;
}
