{ pkgs, ... }:
let
  base = [
    # base packages
  ];

  development = [
    # base packages
  ];

  containers = [
    # pkgs.distrobox
    # pkgs.distrobox-tui
  ];

  virtualization = [
    # pkgs.libvirt
    # pkgs.qemu
    # pkgs.OVMFFull
  ];

  storage = [ pkgs.btrfs-progs ];

  desktop = [
    pkgs.baobab
    pkgs.brightnessctl
  ];

  wine = [
    # pkgs.wineWow64Packages.stable
    # pkgs.wineWow64Packages.waylandFull
    # pkgs.winetricks
  ];

  extras = [
    # inputs.agenix.packages."x86_64-linux".default
    pkgs.protonvpn-gui
    pkgs.deja-dup
    pkgs.peazip
    pkgs.mat2
  ];
in
{
  environment.systemPackages = storage ++ desktop ++ wine ++ extras;
}
