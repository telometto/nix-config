# Shared home-manager configuration for all users
{ config, lib, pkgs, VARS, ... }:

{
  # Common programs for all users
  programs = {
    home-manager.enable = true;

    # Terminal and shell
    atuin = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      #settings = {
      #  key_path = "/opt/sec/atuin-file";
      #};
    };

    bash = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration =
        true; # Enable VTE integration to track current directory
      historyControl = [ "erasedups" ]; # Remove duplicates in history
    };

    bat = { enable = true; };

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

    fastfetch = { enable = true; };

    fzf = {
      enable = true;

      tmux.enableShellIntegration = true;
    };

    zsh = {
      enable = true;

      enableCompletion = true;
      autosuggestion = { enable = true; };
      syntaxHighlighting = { enable = true; };
      autocd = true;
      enableVteIntegration = true;

      history = {
        expireDuplicatesFirst = true;
        extended = true;
        ignoreAllDups = true;
      };

      initContent = lib.mkMerge [
        (lib.mkOrder 550
          "source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme")

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

    # Development tools
    git = { # duplicate /home/zeno/Downloads/nix-config/home/programs/desktop-programs.nix
      enable = true;
      userName = "telometto";
      userEmail = "65364211+telometto@users.noreply.github.com";

      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = false;
        core.autocrlf = "input";

        # GPG signing configuration
        commit.gpgSign = true;
        tag.gpgSign = true;

        gpg = {
          format = "ssh";
          ssh = {
            defaultKeyCommand = "sh -c 'echo key::$(ssh-add -L | tail -n1)'";
            allowedSignersFile =
              "${config.home.homeDirectory}/.ssh/allowed_signers";
          };
        };

        user.signingKey = "${config.home.homeDirectory}/.ssh/github-key.pub";
      };

      includes = [{
        condition = "gitdir:~/.versioncontrol/github/";
        contents.user.email = "65364211+telometto@users.noreply.github.com";
      }];

      diff-so-fancy.enable = true;
    };

    # Text editors
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

    # Terminal multiplexer
    tmux = {
      enable = true;
      clock24 = true;
      mouse = false;
    };

    # GPG
    gpg = {
      enable = true;

      homedir = "${config.home.homeDirectory}/.gnupg";

      mutableTrust = false; # Allow trustdb modifications
      mutableKeys = false; # Allow key modifications

      settings = {
        # General settings
        no-greeting = true; # Disable the GnuPG greeting message
        no-emit-version = true; # Do not emit the version of GnuPG
        no-comments = false; # Do not write comments in clear text signatures

        # Export options
        export-options = "export-minimal"; # Export minimal information
        keyid-format = "0xlong"; # Use long key IDs
        with-fingerprint = true; # Include key fingerprints in key listings
        with-keygrip = true; # Include key grip in key listings

        # List and verify options
        list-options = "show-uid-validity"; # Show the validity of user IDs
        verify-options =
          "show-uid-validity show-keyserver-urls"; # Show the validity of user IDs and keyserver URLs

        # Cipher and digest preferences
        personal-cipher-preferences =
          "AES256"; # Set the personal cipher preferences
        personal-digest-preferences =
          "SHA512"; # Set the personal digest preferences
        default-preference-list =
          "SHA512 SHA384 SHA256 RIPEMD160 AES256 TWOFISH BLOWFISH ZLIB BZIP2 ZIP Uncompressed"; # Set the default preference list
        cipher-algo = "AES256"; # Set the cipher algorithm
        digest-algo = "SHA512"; # Set the digest algorithm
        cert-digest-algo = "SHA512"; # Set the certificate digest algorithm
        compress-algo = "ZLIB"; # Set the compression algorithm

        # Disable weak algorithms
        disable-cipher-algo = "3DES"; # Disable 3DES
        weak-digest = "SHA1"; # Disable SHA1

        # String-to-key (S2K) settings
        s2k-cipher-algo = "AES256"; # Set the S2K cipher algorithm
        s2k-digest-algo = "SHA512"; # Set the S2K digest algorithm
        s2k-mode = "3"; # Set the S2K mode
        s2k-count = "65011712"; # Set the S2K count
      };
    };

    # SSH is on hold until config permissions are fixed; see https://github.com/nix-community/home-manager/issues/322
    # For now, resorting to non-home-manager configuration

    ssh = {
      enable = true;

      addKeysToAgent = "yes";
      # controlMaster = "auto";
      # controlPath = "/some/path/%r@%h:%p";
      # controlPersist = "yes";
      # compression = true;
      # extraConfig = ""; # Strings concatenated with "\n"
      # extraOptionOverrides = ""; # Attribute set of strings
      # forwardAgent = true;
      # hashKnownHosts = true;
      # includes = [ ]; # List of strings
      # serverAliveCountMax = 1; # Positive integer
      # serverAliveInterval = 1;
      # userKnownHostsFile = ""; # String

      matchBlocks = {
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
          # setEnv = "TERM=xterm-256color";
        };
      };
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

  };

  # Common services
  services = {
    # GPG agent
    gpg-agent = {
      enable = true;

      enableSshSupport = false;
      enableExtraSocket = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableScDaemon = false; # Smartcard

      defaultCacheTtl = 34560000; # 400 days
      defaultCacheTtlSsh = 34560000; # 400 days
      maxCacheTtl = 34560000; # 400 days
      maxCacheTtlSsh = 34560000; # 400 days
    };

    # SSH agent
    ssh-agent = { enable = true; };
  };

  # XDG configuration
  xdg = {
    enable = true;

    autostart.enable = true;

    cacheHome = "${config.home.homeDirectory}/.cache";
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    stateHome = "${config.home.homeDirectory}/.local/state";

    userDirs = {
      enable = true;
      createDirectories = true;
      # desktop = "$HOME/Desktop";
      # documents = "$HOME/Documents";
      # download = "$HOME/Downloads";
      # music = "$HOME/Music";
      # pictures = "$HOME/Pictures";
      # videos = "$HOME/Videos";
      # templates = "$HOME/Templates";
      # publicShare = "$HOME/Public";
    };

    # mimeApps = {
    #   enable = true;
    #   defaultApplications = {
    #     "application/pdf" = [ "firefox.desktop" ];
    #     "text/html" = [ "firefox.desktop" ];
    #     "x-scheme-handler/http" = [ "firefox.desktop" ];
    #     "x-scheme-handler/https" = [ "firefox.desktop" ];
    #     "x-scheme-handler/about" = [ "firefox.desktop" ];
    #     "x-scheme-handler/unknown" = [ "firefox.desktop" ];
    #     "text/plain" = [ "micro.desktop" ];
    #     "application/json" = [ "micro.desktop" ];
    #     "application/x-shellscript" = [ "micro.desktop" ];
    #   };
    # };
  };

  # Home packages available to all users
  home.packages = with pkgs; [ xdg-utils xdg-user-dirs ];
}
