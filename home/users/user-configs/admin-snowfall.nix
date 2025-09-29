# User-specific configuration for admin user on snowfall host
{ config, pkgs, ... }:
{
  # User-specific packages for admin on snowfall
  home.packages = with pkgs; [
    variety # Wallpaper changer
    polychromatic # Razer configuration tool
    tuxguitar # Guitar tablature editor and player
    pgadmin4-desktopmode # PostgreSQL administration tool
    vorta # Borg backup GUI
  ];

  # Enable file management for SSH configuration
  hm.files = {
    enable = true;

    sshConfig = {
      enable = true;

      # SSH host configurations
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
      };

      # SSH allowed signers for commit verification
      allowedSigners = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPkY5zM9mkSM3E6V8S12QpLzdYgYtKMk2TETRhW5pykE 65364211+telometto@users.noreply.github.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMdEoq7fpm5wfF6GKpOaebHJUccxcPimffler4ohmRsH 226052356+amonomega@users.noreply.github.com"
      ];
    };
  };

  # GPG Agent configuration with SSH keys
  hm.services.gpgAgent = {
    enable = true;
    enableSsh = true;
    sshKeys = [
      "B77831B9FEB4A078E8C0A92F5CD3DD364C2622F6"
      "42E575D7C88F6316332022D0A9472AE2951CAB47"
      "40C5082C45D9BD46357E15AA7BE343A6D068C74D"
    ];
  };
}
