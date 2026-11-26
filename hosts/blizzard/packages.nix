{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.crowdsec-firewall-bouncer
    pkgs.btrfs-progs
    pkgs.zfs
    pkgs.zfstools
    pkgs.shadow
  ];
}
