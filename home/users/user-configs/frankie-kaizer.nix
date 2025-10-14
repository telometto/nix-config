# User-specific configuration for frankie on kaizer host
# This file is automatically imported only for frankie user on kaizer
{
  lib,
  config,
  pkgs,
  ...
}:
{
  # Frankie-specific packages on kaizer
  home.packages = with pkgs; [
    # Add frankie's preferred applications here
  ];

  # Frankie's personal configurations
  # Example customizations:
  # programs.git.userEmail = "frankie@example.com";
  # programs.vscode.extensions = [ ... ];
}
