/*
  This Nix expression defines shared environment configuration defaults.
  It sets up environment variables that are applied globally.
*/

{ config, lib, pkgs, ... }:

{
  environment = {
    variables = {
      # Set the default editor
      EDITOR = "micro";
      # Set the default pager
      #PAGER = "less";
    };
  };
}
