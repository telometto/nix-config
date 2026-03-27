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

  desktop = [ pkgs.baobab ];

  wine = [
    # pkgs.wineWow64Packages.stable
    # pkgs.wineWow64Packages.waylandFull
    # pkgs.winetricks
  ];

  extras = [
    # inputs.agenix.packages."x86_64-linux".default
    pkgs.proton-vpn
    pkgs.deja-dup
    pkgs.peazip
    pkgs.mat2
  ];
in
{
  # Compose from local categories; add/remove lists as needed
  environment.systemPackages = storage ++ desktop ++ wine ++ extras;
}
