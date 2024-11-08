# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Shell utilities
    bash # Bourne Again SHell
    bash-completion # Bash command completion
    zsh # Z shell
    zsh-autocomplete # Zsh command autocompletion
    blesh # bash-autocompleter

    # System utilities
    coreutils-full # GNU core utilities
    curl # Command line tool for transferring data with URLs
    eza # Modern replacement for 'ls'
    ffmpeg # Multimedia framework for handling video, audio, and other multimedia files
    kexec-tools # Tools for loading a new kernel
    microcodeIntel # Intel CPU microcode updates
    linuxHeaders # Linux kernel headers
    nftables # Netfilter tables for packet filtering
    lm_sensors # Hardware monitoring
    micro # Terminal-based text editor
    fastfetch # Neofetch-like tool for displaying system information
    nettools # Network tools like ifconfig, netstat, etc.
    p7zip # File archiver with high compression ratio
    realmd # Discover and join identity domains
    rng-tools # Random number generator tools
    rsync # Fast, versatile, remote (and local) file-copying tool
    smartmontools # Control and monitor storage systems using S.M.A.R.T.
    tree # Display directories as trees
    wget # Network downloader
    xclip # Command line interface to the X11 clipboard
    usbutils # USB device related utilities
    udiskie # Removable disk automounter
    udisks # Disk management service

    # Development tools
    git # Version control system, required by flakes
    pipx # Install and run Python applications in isolated environments
    poetry # Python dependency management and packaging
    tmux # Terminal multiplexer
    tmuxPlugins.dracula # Dracula theme for tmux
    tmuxPlugins.gruvbox # Gruvbox theme for tmux

    # Networking tools
    wireguard-tools # Tools for the WireGuard VPN
    cloudflared # Cloudflare's DoH and DoT client
    cloudflare-dyndns # Dynamic DNS client for Cloudflare

    # Monitoring tools
    bat # Cat clone with syntax highlighting and Git integration
    btop # Resource monitor

    direnv
    fzf
    nix-direnv
    zoxide
    glibcLocales
  ];
}
