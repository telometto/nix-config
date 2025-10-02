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
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
      };

      bash = {
        enable = true;
        enableCompletion = true;
        enableVteIntegration = true;
        historyControl = [ "erasedups" ];
      };

      bat.enable = true;

      btop.enable = true;

      direnv = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      eza = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        git = true;
        icons = "always";
        extraOptions = [
          "--color=always"
          "--group"
          "--group-directories-first"
          "--header"
          "--long"
        ];
      };

      fzf = {
        enable = true;
        tmux.enableShellIntegration = true;
      };

      micro = {
        enable = true;
        settings = {
          autosu = true;
          mkparents = true;
          colorscheme = "gruvbox-tc";
          hlsearch = true;
          hltaberrors = true;
          tabtospaces = true;
        };
      };

      ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks = {
          "*" = {
            addKeysToAgent = "yes";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";
          };
          "github.com" = {
            hostname = "ssh.github.com";
            port = 443;
            user = "git";
            identitiesOnly = true;
            identityFile = "${config.home.homeDirectory}/.ssh/github-key";
          };
          "192.168.*" = {
            forwardAgent = true;
            identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
            identitiesOnly = true;
          };
        };
      };

      tmux = {
        enable = true;
        clock24 = true;
        mouse = false;
      };

      zellij = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;

        # TODO: Declaratively configure Zellij
        # settings = {
        #   theme = "gruvbox-dark";
        # };
      };

      zoxide = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
      };

      zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        autocd = true;
        enableVteIntegration = true;

        history = {
          expireDuplicatesFirst = true;
          extended = true;
          ignoreAllDups = true;
        };

        initContent = lib.mkMerge [
          (lib.mkOrder 550 "source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme")

          (lib.mkOrder 1000 "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh")
        ];

        oh-my-zsh = {
          enable = true;

          plugins = [
            #"autoenv"
            "colored-man-pages"
            "colorize"
            "command-not-found"
            "common-aliases"
            # "copybuffer"
            "direnv"
            "git"
            "emoji"
            "eza"
            "fzf"
            "gpg-agent"
            "podman"
            # "ssh-agent"
            "sudo"
            "systemd"
            "tailscale"
            "tmux"
            "vscode"
            "zoxide"
            #"zsh-autosuggestions"
            #"zsh-syntax-highlighting"
          ];
        };
      };
    };

    home.packages = [ pkgs.zsh-powerlevel10k ];
  };
}
