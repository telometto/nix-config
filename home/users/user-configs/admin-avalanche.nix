# User-specific configuration for admin user on avalanche host
{ lib, config, pkgs, VARS, ... }: {
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
}
