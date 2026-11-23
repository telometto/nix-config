# Packages shared by every managed user, on desktops and servers.
{ pkgs, ... }:
{
  home.packages = [ pkgs.dupe-krill ];
}
