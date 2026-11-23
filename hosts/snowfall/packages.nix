{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.btrfs-progs
    pkgs.baobab
    pkgs.proton-vpn
    pkgs.deja-dup
    pkgs.peazip
    pkgs.mat2
  ];
}
