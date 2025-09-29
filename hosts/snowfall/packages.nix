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
    pkgs.wineWowPackages.stable
    pkgs.wineWowPackages.waylandFull
    pkgs.winetricks
  ];

  extras = [
    # inputs.agenix.packages."x86_64-linux".default
  ];
in {
  # Compose from local categories; add/remove lists as needed
  environment.systemPackages = storage ++ desktop ++ wine ++ extras;

  fonts.packages = [
    pkgs.google-fonts
    pkgs.ibm-plex
    pkgs.meslo-lgs-nf
    pkgs.nerd-fonts.ubuntu
    pkgs.nerd-fonts.inconsolata
    pkgs.nerd-fonts.mononoki
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.tinos
    pkgs.noto-fonts
    pkgs.noto-fonts-color-emoji
  ];
}
