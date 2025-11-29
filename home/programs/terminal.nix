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
        enable = lib.mkDefault true;
        enableBashIntegration = lib.mkDefault true;
        enableZshIntegration = lib.mkDefault true;
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
        extraOptions = [
          "--color=always"
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

      ssh = {
        enable = lib.mkDefault true;
        enableDefaultConfig = lib.mkDefault false;
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
        enable = lib.mkDefault true;
        clock24 = lib.mkDefault true;
        mouse = lib.mkDefault false;
      };

      zellij = {
        enable = lib.mkDefault true;
        enableBashIntegration = lib.mkDefault true;
        enableZshIntegration = lib.mkDefault true;

        # TODO: Declaratively configure Zellij
        # settings = {
        #   theme = "gruvbox-dark";
        # };
      };

      zoxide = {
        enable = lib.mkDefault true;
        enableBashIntegration = lib.mkDefault true;
        enableZshIntegration = lib.mkDefault true;
      };

      zsh = {
        enable = lib.mkDefault true;
        enableCompletion = lib.mkDefault true;
        autosuggestion.enable = lib.mkDefault true;
        syntaxHighlighting.enable = lib.mkDefault true;
        autocd = lib.mkDefault true;
        enableVteIntegration = lib.mkDefault true;

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
          enable = lib.mkDefault true;

          plugins = [
            #"autoenv"
            "colored-man-pages"
            "colorize"
            "command-not-found"
            "common-aliases"
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
