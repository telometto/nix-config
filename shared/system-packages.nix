# Common package definitions to reduce duplication
{ config, lib, pkgs, VARS, ... }:

let mylib = import ../lib { inherit lib VARS; };
in {
  # Common packages for all systems
  base = [
    # inputs.agenix.packages."x86_64-linux".default  # unavailable in inputs; commented

    # Shells and Shell Enhancements
    pkgs.bash-completion
    pkgs.zsh-autocomplete
    pkgs.blesh

    # Core Utilities
    pkgs.coreutils-full
    pkgs.util-linux

    # Networking Tools
    pkgs.curl
    pkgs.nettools
    pkgs.wget
    pkgs.wireguard-tools
    pkgs.bridge-utils

    # System Monitoring and Management
    pkgs.lm_sensors
    pkgs.kexec-tools
    pkgs.linuxHeaders
    pkgs.rng-tools
    pkgs.smartmontools
    pkgs.rsync
    pkgs.tree
    pkgs.btop

    # Multimedia Tools
    pkgs.ffmpeg

    # Text Editors
    pkgs.micro

    # Development Tools
    pkgs.automake
    pkgs.clang
    pkgs.cmake
    pkgs.autoconf
    pkgs.git
    pkgs.pipx

    # Terminal Multiplexers and Plugins
    pkgs.tmux
    pkgs.tmuxPlugins.dracula
    pkgs.tmuxPlugins.gruvbox

    # Miscellaneous Tools
    pkgs.eza
    pkgs.p7zip
    pkgs.realmd
    pkgs.xclip
    pkgs.bat
    pkgs.direnv
    pkgs.fzf
    pkgs.nix-direnv
    pkgs.zoxide
    pkgs.sbctl
    pkgs.colmena
    pkgs.lsof
    pkgs.envsubst

    # AppArmor toolchain
    pkgs.apparmor-bin-utils
    pkgs.apparmor-pam
    pkgs.apparmor-parser
    pkgs.apparmor-profiles
    pkgs.apparmor-utils
    pkgs.libapparmor

    # tpm2-related packages
    pkgs.tpm2-tools

    # Podman toolchain
    pkgs.podman
    pkgs.podman-compose
    pkgs.podman-tui
    pkgs.shadow # Required for rootless podman on ZFS
  ];

  # Desktop-specific packages
  desktop = [
    pkgs.microcode-amd
    pkgs.distrobox
    pkgs.distrobox-tui
    pkgs.fuse3
    pkgs.wineWowPackages.stable
    pkgs.wineWowPackages.waylandFull
    pkgs.winetricks
  ];

  # Laptop-specific packages
  laptop = [ ];

  # Server-specific packages  
  server = [
    pkgs.zfs
    pkgs.zfstools
    pkgs.tmux
    pkgs.rsync
    pkgs.gcr_4
    pkgs.chromaprint
  ];

  fonts = [
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

  development = [ ];
  gaming = [ ];
}
