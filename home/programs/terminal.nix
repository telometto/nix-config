{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hm.programs.terminal;
in
{
  options.hm.programs.terminal = {
    enable = lib.mkEnableOption "Terminal tools and shell configuration";

    atuin.settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "User overrides for Atuin settings merged on top of the module defaults.";
    };

    zellij = {
      enable = lib.mkEnableOption "zellij multiplexer";

      attachToExisting = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to attach to an existing session.";
      };

      exitShellOnExit = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to exit the shell itself on exit.";
      };
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional terminal packages";
    };
  };

  config = lib.mkIf cfg.enable {
    hm.programs.fastfetch.enable = lib.mkDefault true;

    programs = {
      atuin = {
        enable = lib.mkDefault true;

        enableBashIntegration = lib.mkDefault true;
        enableZshIntegration = lib.mkDefault true;

        settings = lib.mkMerge [
          {
            auto_sync = true;
            update_check = false;

            # Prefer history discovery that works well in big git repos.
            search_mode = "daemon-fuzzy";
            filter_mode = "workspace";
            workspaces = true;

            style = "compact";
            inline_height = 20;
            show_preview = true;
            show_help = false;
            enter_accept = true;
          }
          cfg.atuin.settings
        ];
      };

      bash = {
        enable = lib.mkDefault true;
        enableCompletion = lib.mkDefault true;
        enableVteIntegration = lib.mkDefault true;
        historyControl = [ "erasedups" ];
      };

      bat.enable = lib.mkDefault true;

      btop.enable = lib.mkDefault true;

      direnv = {
        enable = lib.mkDefault true;
        enableBashIntegration = lib.mkDefault true;
        enableZshIntegration = lib.mkDefault true;
        nix-direnv.enable = lib.mkDefault true;
      };

      eza = {
        enable = lib.mkDefault true;
        enableBashIntegration = lib.mkDefault true;
        enableZshIntegration = lib.mkDefault true;
        git = lib.mkDefault true;
        icons = lib.mkDefault "always";
        colors = lib.mkDefault "always";
        extraOptions = [
          "--group"
          "--group-directories-first"
          "--header"
          "--long"
        ];
      };

      fzf = {
        enable = lib.mkDefault true;
        tmux.enableShellIntegration = lib.mkDefault true;
      };

      micro = {
        enable = lib.mkDefault true;
        settings = {
          autosu = true;
          mkparents = true;
          colorscheme = "gruvbox-tc";
          hlsearch = true;
          hltaberrors = true;
          tabtospaces = true;
        };
      };

      ssh.enable = lib.mkDefault true;

      tmux = {
        enable = lib.mkDefault true;
        clock24 = lib.mkDefault true;
        mouse = lib.mkDefault false;
      };

      zellij = {
        enable = lib.mkDefault true;
        enableBashIntegration = lib.mkDefault false;
        enableZshIntegration = lib.mkDefault true;
        attachExistingSession = cfg.zellij.attachToExisting;
        inherit (cfg.zellij) exitShellOnExit;
      };

      zoxide = {
        enable = lib.mkDefault true;
        enableBashIntegration = lib.mkDefault true;
        enableZshIntegration = lib.mkDefault true;
      };
    };
  };
}
