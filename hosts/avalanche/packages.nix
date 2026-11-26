{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.btrfs-progs
    pkgs.baobab
    pkgs.brightnessctl
    pkgs.proton-vpn
    pkgs.deja-dup
    pkgs.peazip
    pkgs.mat2
  ];
}
