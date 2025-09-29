# Automatically imported
{ lib, pkgs, ... }:
let
  base = [
    pkgs.bash-completion
    pkgs.zsh-autocomplete
    pkgs.blesh
    pkgs.coreutils-full
    pkgs.util-linux
    pkgs.curl
    pkgs.eza
    pkgs.p7zip
    pkgs.xclip
    pkgs.bat
    pkgs.direnv
    pkgs.fzf
    pkgs.nix-direnv
    pkgs.zoxide
    pkgs.lsof
    pkgs.envsubst
    pkgs.tree
    pkgs.btop
    pkgs.ffmpeg
    pkgs.micro
  ];

  networking = [
    pkgs.realmd
    pkgs.nettools
    pkgs.wget
    pkgs.wireguard-tools
    pkgs.bridge-utils
  ];

  system = [
    pkgs.lm_sensors
    pkgs.kexec-tools
    pkgs.linuxHeaders
    pkgs.rng-tools
    pkgs.smartmontools
    pkgs.rsync
  ];

  development = [
    pkgs.automake
    pkgs.clang
    pkgs.cmake
    pkgs.autoconf
    pkgs.git
    pkgs.pipx
    pkgs.tmux
    pkgs.tmuxPlugins.dracula
    pkgs.tmuxPlugins.gruvbox
  ];

  storage = [
    pkgs.libnfs
    pkgs.nfs-utils
    pkgs.fuse3
    pkgs.usbutils
    pkgs.udiskie
    pkgs.udisks
  ];

  containers = [
    pkgs.podman-compose
    pkgs.podman-tui
  ];

  security = [
    pkgs.sbctl
    pkgs.apparmor-bin-utils
    pkgs.apparmor-pam
    pkgs.apparmor-parser
    pkgs.apparmor-profiles
    pkgs.apparmor-utils
    pkgs.libapparmor
    pkgs.tpm2-tools
  ];
in
{
  environment.systemPackages = lib.concatLists [
    base
    networking
    system
    development
    storage
    containers
    security
  ];

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

  nixpkgs.config.allowUnfree = lib.mkDefault true;
}
