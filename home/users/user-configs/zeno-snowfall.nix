# User-specific configuration for admin user on snowfall host
# This file is automatically imported only for the admin user on snowfall
{
  lib,
  config,
  pkgs,
  ...
}:
{
  # User-specific packages for admin on snowfall
  home.packages = [
    pkgs.variety # Wallpaper changer
    pkgs.polychromatic # Razer configuration tool
    # pkgs.tuxguitar # Guitar tablature editor and player - TEMPORARILY DISABLED: build failure due to swt 4.34 deprecated gdk-pixbuf APIs (https://github.com/NixOS/nixpkgs/pull/462225)
    pkgs.pgadmin4-desktopmode # PostgreSQL administration tool
    pkgs.vorta # Borg backup GUI
    pkgs.hugo # static website engine
    pkgs.signal-desktop
    pkgs.logseq
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

          "ssh.git.*" = {
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

    services = {
      sshAgent.enable = true;
      gpgAgent = {
        enable = true;
        enableSsh = false;
      };
    };
  };
}
