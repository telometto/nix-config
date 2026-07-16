# User-specific configuration for frankie user on snowfall host
# This file is automatically imported only for the frankie user on snowfall
{ pkgs, ... }:
{
  # User-specific packages for frankie on snowfall
  home.packages = [
    pkgs.polychromatic # Razer configuration tool
  ];
}
