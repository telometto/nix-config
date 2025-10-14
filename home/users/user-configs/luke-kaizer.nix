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
  home.packages = with pkgs; [ ];
}
