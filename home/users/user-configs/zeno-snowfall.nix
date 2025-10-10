# User-specific configuration for admin user on snowfall host
# This file is automatically imported only for the admin user on snowfall
{
  lib,
  config,
  pkgs,
  ...
}:
let
  sshAddKeysScript = pkgs.writeShellScript "ssh-add-keys" ''
    set -eu

    export SSH_ASKPASS="${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"
    export SSH_ASKPASS_REQUIRE="prefer"

    for key in \
      "${config.home.homeDirectory}/.ssh/github-key" \
      "${config.home.homeDirectory}/.ssh/amonomega" \
      "${config.home.homeDirectory}/.ssh/id_ed25519"
    do
      if [ -f "$key" ]; then
        ${pkgs.openssh}/bin/ssh-add -q "$key" </dev/null || true
      fi
    done
  '';
in
{
  # User-specific packages for admin on snowfall
  home.packages = with pkgs; [
    variety # Wallpaper changer
    polychromatic # Razer configuration tool
    tuxguitar # Guitar tablature editor and player
    pgadmin4-desktopmode # PostgreSQL administration tool
    vorta # Borg backup GUI
    # pkgs.jellyfin-media-player
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
    # Use gpg-agent for GPG only; ssh-agent handles SSH keys
    services = {
      sshAgent.enable = true;
      gpgAgent = {
        enable = true;
        enableSsh = false;
      };
    };
  };

  systemd.user.services."ssh-add-keys" = {
    Unit = {
      Description = "Load SSH keys into the agent";
      After = [
        "graphical-session.target"
        "kwallet.service"
        "ssh-agent.service"
      ];
      Wants = [
        "graphical-session.target"
        "kwallet.service"
        "ssh-agent.service"
      ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "SSH_ASKPASS=${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"
        "SSH_ASKPASS_REQUIRE=prefer"
      ];
      PassEnvironment = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "DBUS_SESSION_BUS_ADDRESS"
        "XAUTHORITY"
      ];
      ExecStart = sshAddKeysScript;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
