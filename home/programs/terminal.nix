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

      ssh.enable = lib.mkDefault true;

      tmux = {
        enable = lib.mkDefault true;
        clock24 = lib.mkDefault true;
        mouse = lib.mkDefault false;
      };

      zellij = {
        enable = lib.mkDefault true;
        enableBashIntegration = lib.mkDefault true;
        enableZshIntegration = lib.mkDefault true;
        attachExistingSession = lib.mkDefault true;
      };

      zoxide = {
        enable = lib.mkDefault true;
        enableBashIntegration = lib.mkDefault true;
        enableZshIntegration = lib.mkDefault true;
      };

      zsh = {
        enable = lib.mkDefault true;
        enableCompletion = lib.mkDefault true;
        autocd = lib.mkDefault true;
        enableVteIntegration = lib.mkDefault true;
        dotDir = "${config.xdg.configHome}/zsh";

        setOptions = [
          "EXTENDED_HISTORY"
          "SHARE_HISTORY"
          "HIST_REDUCE_BLANKS"
          "HIST_VERIFY"
          "NO_BEEP"
          "INTERACTIVE_COMMENTS"
          "CORRECT"
        ];

        autosuggestion = {
          enable = lib.mkDefault true;
          strategy = [ "history" "completion" ];
          highlight = "fg=#666666";
        };

        syntaxHighlighting = {
          enable = lib.mkDefault true;
          highlighters = [ "main" "brackets" "pattern" "cursor" ];
          patterns = {
            "rm -rf *" = "fg=white,bold,bg=red";
          };
        };

        sessionVariables = {
          kaizerAddr = "root@kaizer.boreal-ruler.ts.net";
        };

        shellAliases = {
          localNrb = "nixos-rebuild boot --flake .# --sudo";
          localNrs = "nixos-rebuild switch --flake .# --sudo";
          targetNrb = "nixos-rebuild boot --flake .#$MACH --build-host $TARGET --target-host $TARGET --ask-sudo-password";

          mountNfs = "sudo mount -t nfs";
          umountNfs = "sudo umount";
          unRar = "NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#unrar e";

          bSsh = "ssh zeno@192.168.2.100";
          sSsh = "ssh zeno@192.168.2.101";
          aSsh = "ssh zeno@192.168.2.234";

          bTsh = "tailscale ssh zeno@blizzard";
          sTsh = "tailscale ssh zeno@snowfall";
          aTsh = "tailscale ssh zeno@avalanche";
          kTsh = "tailscale ssh root@kaizer";
        };

        history = {
          expireDuplicatesFirst = true;
          extended = true;
          ignoreAllDups = true;
        };

        dirHashes = {
          nix = "/home/zeno/.versioncontrol/github/projects/personal/nix-config";
          projects = "/home/zeno/.versioncontrol/github/projects";
        };

        siteFunctions = {
          mkcd = ''
            mkdir --parents "$1" && cd "$1"
          '';
          extract = ''
            if [[ -f "$1" ]]; then
              case "$1" in
                *.tar.bz2) tar xjf "$1" ;;
                *.tar.gz)  tar xzf "$1" ;;
                *.tar.xz)  tar xJf "$1" ;;
                *.bz2)     bunzip2 "$1" ;;
                *.gz)      gunzip "$1" ;;
                *.tar)     tar xf "$1" ;;
                *.tbz2)    tar xjf "$1" ;;
                *.tgz)     tar xzf "$1" ;;
                *.zip)     unzip "$1" ;;
                *.Z)       uncompress "$1" ;;
                *.7z)      7z x "$1" ;;
                *)         echo "Cannot extract '$1'" ;;
              esac
            else
              echo "'$1' is not a valid file"
            fi
          '';
        };

        initContent = lib.mkMerge [
          (lib.mkOrder 550 "source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme")

          (lib.mkOrder 1000 "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh")
        ];

        oh-my-zsh = {
          enable = lib.mkDefault true;

          plugins = [
            "colored-man-pages"
            "colorize"
            "command-not-found"
            "common-aliases"
            "git"
            "emoji"
            "gpg-agent"
            "podman"
            "sudo"
            "systemd"
            "tailscale"
            "tmux"
            "vscode"
          ];
        };
      };
    };

    home.packages = [ pkgs.zsh-powerlevel10k ];
  };
}
