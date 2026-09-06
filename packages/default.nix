{ pkgs }:
let
  libdrmtap = pkgs.callPackage ./libdrmtap/package.nix { };
in
{
  inherit libdrmtap;
  rustdesk-unattended-wayland = pkgs.callPackage ./rustdesk-unattended-wayland/package.nix {
    inherit libdrmtap;
  };
}
