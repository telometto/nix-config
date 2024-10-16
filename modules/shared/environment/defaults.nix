# Host-specific system configuration defaults
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
