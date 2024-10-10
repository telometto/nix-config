# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    apparmor-bin-utils
    apparmor-kernel-patches
    apparmor-pam
    apparmor-parser
    apparmor-profiles
    apparmor-utils
    libapparmor
    bash-completion
    bat
    btop
    cockpit
    coreutils-full
    curl
    eza
    ffmpeg
    git # Required by flakes
    gnupg
    kexec-tools
    microcodeIntel
    linuxHeaders
    nftables
    lanzaboote-tool # Required for Secure Boot
    lm_sensors
    micro
    fastfetch
    nettools
    libnfs
    nfs-utils
    p7zip
    pipx
    podman
    podman-compose
    podman-tui
    poetry
    realmd
    rng-tools
    rsync 
    smartmontools
    tmux
    tmuxPlugins.dracula
    tmuxPlugins.gruvbox
    tree
    wireguard-tools
    wget
    xclip
    sanoid
    shadow # Required by rootless podman on ZFS
    zfs
    zfstools
    zsh
    zsh-autocomplete
    atuin
    blesh
    cloudflared
    cloudflare-dyndns

    docker
    docker-client
    docker-compose
    docker-compose-language-service
    docker-gc

	containerd
    k3s

    sbctl

    (wrapHelm kubernetes-helm {
      plugins = with pkgs.kubernetes-helmPlugins; [
        helm-secrets
        helm-diff
        helm-s3
        helm-git
      ];
    })
  ];
}
