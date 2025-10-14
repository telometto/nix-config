# User-specific configuration for luke on kaizer host
# This file is automatically imported only for luke user on kaizer
{
  lib,
  config,
  pkgs,
  ...
}:
{
  # Luke-specific packages on kaizer
  home.packages = with pkgs; [
    # Add luke's preferred applications here
    # Based on nix-conf, luke had: micro, microcode-amd in user packages
    # but these are likely already in system packages
  ];

  # Luke's personal configurations
  # Example customizations:
  # programs.git.userEmail = "luke@example.com";
  # programs.firefox.profiles.luke = { ... };
}
