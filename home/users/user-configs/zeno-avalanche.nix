# User-specific configuration for admin user on avalanche host
# This file is automatically imported only for the admin user on avalanche
{
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.variety # Wallpaper changer
    #pkgs.tuxguitar # Guitar tablature editor and player
    pkgs.pgadmin4-desktopmode # PostgreSQL administration tool
    pkgs.vorta # Borg backup GUI
    pkgs.logseq
    # (pkgs.jellyfin-media-player.override {
    #   qtwebengine = pkgs.kdePackages.qtwebengine; # overridden due to CVEs
    # }) # disabled due to version mismatch; kept as reference
  ];

  hm = {
    programs = {
      development.extraPackages = [
        pkgs.vscode
        pkgs.jetbrains.idea-oss
      ];

      media.jf-mpv.enable = false;
    };

    files = {
      enable = true;
      sshConfig = {
        enable = true;

        hosts = {
          "*" = {
            ForwardAgent = "yes";
            AddKeysToAgent = "yes";
            Compression = "yes";
          };

          "github-personal" = {
            Hostname = "ssh.github.com";
            Port = "443";
            User = "git";
            IdentityFile = "${config.home.homeDirectory}/.ssh/github-key";
          };

          "github-work" = {
            Hostname = "github.com";
            User = "git";
            IdentityFile = "${config.home.homeDirectory}/.ssh/amonomega";
          };

          "192.168.*" = {
            IdentityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
            IdentitiesOnly = "yes";
            SetEnv = "TERM=xterm-256color";
          };

          "ssh-git.*" = {
            User = "git";
            ProxyCommand = "${pkgs.cloudflared.out}/bin/cloudflared access ssh --hostname %h";
          };
        };

        allowedSigners = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPkY5zM9mkSM3E6V8S12QpLzdYgYtKMk2TETRhW5pykE 65364211+telometto@users.noreply.github.com"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMdEoq7fpm5wfF6GKpOaebHJUccxcPimffler4ohmRsH 226052356+amonomega@users.noreply.github.com"
        ];
      };
    };
  };
}
