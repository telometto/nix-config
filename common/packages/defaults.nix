/**
 * This Nix expression defines a set of system packages to be installed in the environment.
 * It includes a variety of tools and utilities grouped by their functionality.
 */
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Shells and Shell Enhancements
    bash # Bourne Again SHell
    bash-completion # Bash command completion
    zsh # Z shell
    zsh-autocomplete # Zsh command autocompletion
    blesh # Bash autocompleter

    # Core Utilities
    coreutils-full # GNU core utilities
    util-linux # Miscellaneous system utilities

    # Networking Tools
    curl # Command line tool for transferring data with URLs
    nftables # Netfilter tables for packet filtering
    nettools # Network tools like ifconfig, netstat, etc.
    wget # Network downloader
    wireguard-tools # Tools for the WireGuard VPN
    bridge-utils # Utilities for configuring network bridges

    # System Monitoring and Management
    lm_sensors # Hardware monitoring
    kexec-tools # Tools for loading a new kernel
    linuxHeaders # Linux kernel headers
    rng-tools # Random number generator tools
    smartmontools # Control and monitor storage systems using S.M.A.R.T.
    rsync # Fast, versatile, remote (and local) file-copying tool
    tree # Display directories as trees
    btop # Resource monitor

    # Multimedia Tools
    ffmpeg # Multimedia framework for handling video, audio, and other multimedia files

    # Text Editors
    micro # Terminal-based text editor

    # System Information
    fastfetch # Neofetch-like tool for displaying system information

    # Development Tools
    automake # Tool for automatically generating Makefile.in files
    clang # C language family frontend for LLVM
    cmake # Cross-platform, open-source build system
    autoconf # Generates configuration scripts
    git # Version control system, required by flakes
    pipx # Install and run Python applications in isolated environments
    poetry # Python dependency management and packaging

    # Terminal Multiplexers and Plugins
    tmux # Terminal multiplexer
    tmuxPlugins.dracula # Dracula theme for tmux
    tmuxPlugins.gruvbox # Gruvbox theme for tmux

    # Miscellaneous Tools
    eza # Modern replacement for 'ls'
    p7zip # File archiver with high compression ratio
    realmd # Discover and join identity domains
    xclip # Command line interface to the X11 clipboard
    bat # Cat clone with syntax highlighting and Git integration
    direnv # Environment switcher for the shell
    fzf # Command-line fuzzy finder
    nix-direnv # Integration of direnv with Nix
    zoxide # Smarter cd command
    sbctl # Secure Boot key manager
    colmena # Remote management tool
    lsof

    # Fonts and Themes
    google-fonts # Collection of Google Fonts
    ibm-plex # IBM Plex font family
    meslo-lgs-nf # Meslo Nerd Font patched for Powerlevel10k
    # Nerd fonts
    nerd-fonts.ubuntu
    nerd-fonts.inconsolata
    nerd-fonts.mononoki
    nerd-fonts.fira-code
    nerd-fonts.tinos
  ];
}
