# User-specific configuration for admin user on avalanche host
# This file is automatically imported only for the admin user on avalanche
{
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    variety # Wallpaper changer
    polychromatic # Razer configuration tool
    tuxguitar # Guitar tablature editor and player
    pgadmin4-desktopmode # PostgreSQL administration tool
    # vorta # Borg backup GUI
    # (pkgs.jellyfin-media-player.override {
    #   qtwebengine = pkgs.kdePackages.qtwebengine; # overridden due to CVEs
    # }) # disabled due to version mismatch; kept as reference
  ];
  # Enable file management for SSH configuration
  hm = {
    programs = {
      development.extraPackages = [
        pkgs.vscode
        # pkgs.jetbrains.idea-community-bin # disabled until lidbm issue has been solved
      ];
    };

    files = {
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
  };
}
