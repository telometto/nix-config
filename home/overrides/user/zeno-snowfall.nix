# User-specific configuration for zeno on snowfall host
# This file is automatically imported only for zeno on snowfall
{
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./zeno-desktop-ssh.nix ];

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
    pkgs.uv
    pkgs.filen-desktop
    pkgs.filen-cli
    pkgs.nodejs
    pkgs.annotation-mono
    pkgs.jellyfin-desktop
    pkgs.bubblewrap
  ]
  ++ (with pkgs.sweethome3d; [
    application
    furniture-editor
    textures-editor
  ]);

  hm = {
    programs = {
      codex = {
        enable = true;
        preferXdgDirectories = false;
        mutableSettings = true;

        # Merge these preferences into ~/.codex/config.toml while preserving
        # local MCP credentials, project trust, and plugin/skill state.
        settings = {
          model = "gpt-6.1-sol";
          model_reasoning_effort = "max";
          plan_mode_reasoning_effort = "max";
          personality = "pragmatic";
          approvals_reviewer = "auto_review";
          service_tier = "default";

          features = {
            terminal_resize_reflow = true;
            memories = true;
            network_proxy = true;
            mentions_v2 = true;
            prevent_idle_sleep = true;
            worktrees = true;
            analytics_plan_history = true;
            daemon_auto_start = true;
            login_shell_package_path = true;
          };

          tui = {
            theme = "gruvbox-dark";
            status_line = [
              "model-with-reasoning"
              "context-used"
              "five-hour-limit"
              "weekly-limit"
            ];
            status_line_use_colors = true;
            session_picker_view = "comfortable";
          };
        };
      };

      development = {
        extraPackages = [
          pkgs.vscode
          # pkgs.jetbrains.idea-oss # disabled due to vulnerable package
        ];

        git.lfs = true;
      };

      gitea.enable = true;
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
