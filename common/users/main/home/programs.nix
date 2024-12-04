{ config, lib, pkgs, VARS, ... }:
let
  LANGUAGES = [ "nb-NO" "it-IT" "en-US" ];
in
{
  programs = {
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
      enableVteIntegration = true; # Enable VTE integration to track current directory
      historyControl = [ "erasedups" ]; # Remove duplicates in history
    };

    bat = {
      enable = true;
    };

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

    firefox = {
      enable = true;

      languagePacks = LANGUAGES;

      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableFirefoxAccounts = false;
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
        DontCheckDefaultBrowser = true;
        DisplayBookmarksToolbar = "always";
        DisplayMenuBar = "default-off";
        SearchBar = "unified";

        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
      };
    };

    floorp = {
      enable = true;

      #languagePacks = [ "nb-NO" "it-IT" "en-US" ];
    };

    git = {
      enable = true;

      userName = "telometto";
      userEmail = config.sops.secrets."git/github-prim-email".path;

      includes = [
        {
          condition = "gitdir:~/.versioncontrol/github/";

          contents = {
            user.name = "telometto";
            user.email = config.sops.secrets."git/github-email".path;
            user.signingKey = "0x5A5BF29378C3942B";

            commit.gpgSign = true;

            core.sshCommand = "ssh -i ~/.ssh/id_ed25519";
          };
        }
        {
          condition = "gitdir:~/.versioncontrol/gitlab/";

          contents = {
            user.name = "telometto";
            user.email = config.sops.secrets."git/gitlab-email".path;
            user.signingKey = "0xB7103B8A59566994";

            commit.gpgSign = true;

            core.sshCommand = "ssh -i ~/.ssh/gitlabkey";
          };
        }
      ];

      diff-so-fancy = {
        enable = true;
      };
    };

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
        verify-options = "show-uid-validity show-keyserver-urls"; # Show the validity of user IDs and keyserver URLs

        # Cipher and digest preferences
        personal-cipher-preferences = "AES256"; # Set the personal cipher preferences
        personal-digest-preferences = "SHA512"; # Set the personal digest preferences
        default-preference-list = "SHA512 SHA384 SHA256 RIPEMD160 AES256 TWOFISH BLOWFISH ZLIB BZIP2 ZIP Uncompressed"; # Set the default preference list
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

    keychain = {
      enable = true;

      enableBashIntegration = true;
      enableZshIntegration = true;

      # agents = [ "ssh" ];

      # inheritType = "any";

      keys = [
        "id_ed25519"
        "gitlabkey"
        # "ssh_host_ed25519_key"
        "testkey"
        "zeno-avalanche"
      ];

      extraFlags = [
        # "--eval"
        "--noask"
        "--quiet"
      ];
    };

    mangohud = {
      enable = true;
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

    mpv = {
      enable = true;

      # TODO: Declaratively configure mpv
    };

    /*
      # SSH is on hold until config permissions are fixed; see https://github.com/nix-community/home-manager/issues/322
      # For now, resorting to non-home-manager configuration

      ssh = {
      enable = true;

      addKeysToAgent = "yes";
      #controlMaster = "auto";
      #controlPath = "/some/path/%r@%h:%p";
      #controlPersist = "yes";
      compression = true;
      #extraConfig = ""; # Strings concatenated with "\n"
      #extraOptionOverrides = ""; # Attribute set of strings
      forwardAgent = true;
      #hashKnownHosts = true;
      #includes = [ ]; # List of strings
      #matchBlocks = { }; # Attribute set of attribute sets
      #serverAliveCountMax = 1; # Positive integer
      #serverAliveInterval = 1;
      #userKnownHostsFile = ""; # String
      };
        */

    /*
      thunderbird = {
      enable = true;

      # TODO: Declaratively configure Thunderbird
      };
        */

    tmux = {
      enable = true;
      clock24 = true;
      mouse = false;

      #plugins = {
      #  dracula = {
      #    enable = true;
      #  };
      #
      #  gruvbox = {
      #    enable = true;
      #  };
      #};
    };

    /*
      vscode = {
      enable = true;

      enableUpdateCheck = false; # Disable update checks
      mutableExtensionsDir = true; # Allow extensions to be installed in the user's home directory

      # TODO: Declaratively configure Visual Studio Code
      };
        */

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
      autosuggestion = { enable = true; };
      syntaxHighlighting = { enable = true; };
      autocd = true;
      enableVteIntegration = true;

      history = {
        expireDuplicatesFirst = true;
        extended = true;
        ignoreAllDups = true;
      };

      initExtraBeforeCompInit = ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      '';

      initExtra = ''
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      '';

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
          "ssh-agent"
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
}
