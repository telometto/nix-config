# User-specific configuration for zeno on snowfall host
# This file is automatically imported only for zeno on snowfall
{
  lib,
  pkgs,
  config,
  VARS,
  ...
}:
{
  imports = [ ./zeno-desktop-ssh.nix ];

  hm.security.sops.secrets."gitea/cf_access_id" = {
    mode = "0400";
  };

  hm.security.sops.secrets."gitea/cf_access_secret" = {
    mode = "0400";
  };

  sops.templates."gitea-git-http" = {
    content = ''
      [http "https://git.${VARS.domains.public}/"]
          extraHeader = CF-Access-Client-Id: ${config.sops.placeholder."gitea/cf_access_id"}
          extraHeader = CF-Access-Client-Secret: ${config.sops.placeholder."gitea/cf_access_secret"}
    '';
    mode = "0400";
  };

  programs.git.includes = [
    {
      path = config.sops.templates."gitea-git-http".path;
    }
  ];

  # User-specific packages for admin on snowfall
  home.packages = [
    pkgs.polychromatic # Razer configuration tool
    pkgs.tuxguitar # Guitar tablature editor and player
    pkgs.pgadmin4-desktopmode # PostgreSQL administration tool
    pkgs.vorta # Borg backup GUI
    pkgs.hugo # static website engine
    pkgs.signal-desktop
    # pkgs.logseq # Issues with Electron
    # pkgs.kdePackages.krdc
    pkgs.teams-for-linux
    pkgs.meld
    # pkgs.rustdesk-flutter
    pkgs.lmstudio
    pkgs.podman-desktop
    pkgs.zola
    pkgs.rendercv
    pkgs.claude-code
    pkgs.uv
    pkgs.filen-desktop
    pkgs.filen-cli
    pkgs.codex
    pkgs.nodejs
  ]
  ++ (with pkgs.sweethome3d; [
    application
    furniture-editor
    textures-editor
  ]);

  hm = {
    programs = {
      development = {
        extraPackages = [
          pkgs.vscode
          # pkgs.jetbrains.idea-oss # disabled due to vulnerable package
        ];

        git.lfs = true;
      };
    };

    files.sshAllowedSigners = lib.mkAfter [
      ''telometto@gitea namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINpFgTwAXaVs3LSoVuQsQoylu2G80QzkqFA751naKNUQ''
    ];

    services = {
      sshAgent.enable = true;
      gpgAgent = {
        enable = true;
        enableSsh = false;
      };
    };
  };
}
