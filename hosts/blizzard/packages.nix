{ pkgs, ... }:
let
  media = [
    pkgs.jellyfin-ffmpeg # Conversion tools
    pkgs.jellyfin-web # Web client
    pkgs.jellyseerr # Fork of Overseerr
  ];

  kubernetes = [
    (pkgs.wrapHelm pkgs.kubernetes-helm {
      plugins = [
        pkgs.kubernetes-helmPlugins.helm-secrets
        pkgs.kubernetes-helmPlugins.helm-diff
        pkgs.kubernetes-helmPlugins.helm-s3
        pkgs.kubernetes-helmPlugins.helm-git
      ];
    })
  ];

  security = [ pkgs.crowdsec-firewall-bouncer ];

  storage = [
    pkgs.btrfs-progs
    pkgs.zfs
    pkgs.zfstools
    pkgs.shadow
    pkgs.webzfs
  ];
in
{
  environment.systemPackages = media ++ kubernetes ++ security ++ storage;

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
