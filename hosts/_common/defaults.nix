/**
 * The foundation of all systems. Contains universal settings imported by every host: basic packages, networking fundamentals, shared user settings, and system-wide defaults.
 */
{ config, lib, inputs, pkgs, VARS, ... }:
let
  MEM_MAX = 7500000;
  LANGUAGE = "nb_NO.UTF-8"; # Norwegian Bokmål locale
in {
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.sops-nix.nixosModules.sops
  ];

  users.users.${VARS.users.admin.user} = {
    inherit (VARS.users.admin) description isNormalUser hashedPassword;

    extraGroups = VARS.users.admin.extraGroups ++ lib.optionals (config.networking.hostName == VARS.systems.desktop.hostName) [ "openrazer" ];

    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      VARS.users.admin.sshPubKey
      VARS.users.admin.gpgSshPubKey
    ];
  };

  # Bootloader
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;

      systemd-boot = {
        enable = lib.mkForce false;
        configurationLimit = 3;
      };
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };

    supportedFilesystems = [ "nfs" ];

    kernel.sysctl = {
      "net.core.wmem_max" = MEM_MAX; # For cloudflared tunnel
      "net.core.rmem_max" = MEM_MAX; # For cloudflared tunnel

      # "net.ipv4.ip_forward" = 1; # Tailscale optimization: enable ipv4 forwarding
      # "net.ipv6.conf.all.forwarding" = 1; # Tailscale optimization: enable ipv6 forwarding
    };
  };

  environment = {
    variables = {
      # Set the default editor
      EDITOR = "micro";

      # Set the default pager
      # PAGER = "less";

      # Set the SSH_ASKPASS_REQUIRE
      SSH_ASKPASS_REQUIRE = "prefer";

      # Git configuration
      # GIT_SSH_COMMAND = "ssh -i /etc/ssh/ssh_host_ed25519_key";
    };
  };

  console = {
    useXkbConfig = true; # use xkb.options in tty
    font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
  };

  time.timeZone = "Europe/Oslo";

  i18n = {
    defaultLocale = "en_US.UTF-8";

    # extraLocales = [ ];

    glibcLocales = pkgs.glibcLocales.override { allLocales = true; };

    extraLocaleSettings = {
      LC_ADDRESS = LANGUAGE;
      LC_IDENTIFICATION = LANGUAGE;
      LC_MEASUREMENT = LANGUAGE;
      LC_MONETARY = LANGUAGE;
      LC_NAME = LANGUAGE;
      LC_NUMERIC = LANGUAGE;
      LC_PAPER = LANGUAGE;
      LC_TELEPHONE = LANGUAGE;
      LC_TIME = LANGUAGE;
    };
  };

  nix = {
    config.allowUnfree = true;

    settings = {
      trusted-users = [ "root" "@wheel" ]; # Trusted users; mainly for colmena
      experimental-features = [ "nix-command" "flakes" ]; # Enable Nix command and flakes
      auto-optimise-store = true; # Automatically optimise the Nix store
      download-buffer-size = 536870912; # 512MB download buffer size
    };

    gc = {
      automatic = lib.mkDefault true; # Enable automatic garbage collection
      dates = lib.mkDefault "weekly"; # Run garbage collection weekly
      options = lib.mkDefault "--delete-older-than 3d"; # Delete generations older than 7 days
    };

    optimise = {
      automatic = true;
      dates = [ "02:00" ]; # Run at 2:00 AM
    };

    # nix.settings.access-tokens cannot read secrets from sops-nix, thus the following workaround
    extraOptions = ''
      !include ${config.sops.templates."access-tokens".path}
    '';
  };

  programs = {
    gnupg = {
      agent = {
        enable = true;

        enableSSHSupport = false;

        settings = {
          default-cache-ttl = 34560000; # 400 days
          max-cache-ttl = 34560000; # 400 days
        };
      };
    };

    mtr.enable = true; # traceroute and ping in a single tool

    ssh = {
      startAgent = true;
      enableAskPassword = true;
      forwardX11 = false;
      setXAuthLocation = false;

      extraConfig = ''
        Host *
          ForwardAgent yes
          AddKeysToAgent yes
          Compression yes
          ServerAliveInterval 0
          ServerAliveCountMax 3
          HashKnownHosts no
          UserKnownHostsFile ~/.ssh/known_hosts
          ControlMaster no
          ControlPath ~/.ssh/master-%r@%n:%p
          ControlPersist no
      '';
    };

    zsh.enable = true;
  };

  security = {
    apparmor.enable = true;
    polkit.enable = true;
    tpm2.enable = true;
  };

  services = {
    fstrim.enable = true;
    fwupd.enable = true;
    devmon.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;

    openssh = {
      enable = true;

      banner = "\n:: Welcome back to The Matrix! ::\n\n";

      settings = {
        X11Forwarding = false;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        UsePAM = true;
      };

      # extraConfig = ''X11UseLocalhost no'';

      openFirewall = true;
    };

    timesyncd = {
      enable = true;

      servers = [
        "time.cloudflare.com"
        "0.no.pool.ntp.org"
        "1.no.pool.ntp.org"
        "2.no.pool.ntp.org"
        "3.no.pool.ntp.org"
      ];

      fallbackServers = [
        "0.nixos.pool.ntp.org"
        "1.nixos.pool.ntp.org"
        "2.nixos.pool.ntp.org"
        "3.nixos.pool.ntp.org"
      ];
    };

    xserver = {
      xkb = {
        layout = "no";
        variant = ""; # Example: "variant = dvorak";
        # options = "eurosign:e,caps:escape";
      };
    };

    zram-generator.enable = true;
  };

  zramSwap.enable = true;

  sops = {
    # defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile; #"${inputs.nix-secrets.path}/nix-secrets/secrets/secrets.yaml";
    defaultSopsFormat = "yaml"; # Default format for sops files

    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; # Paths to the host ssh keys
      keyFile = "/var/lib/sops-nix/key.txt"; # Path to the key file
      generateKey = true; # Generate a new key if the keyFile does not exist
    };

    secrets = {
      "tokens/gh-ns-test" = { };
      "tokens/github-ns" = { };
      "tokens/gitlab-fa" = { };
      "tokens/gitlab-ns" = { };
    };

    templates."access-tokens".content = ''
      access-tokens = "github.com=${config.sops.placeholder."tokens/github-ns"}"

      extra-access-tokens = "github.com=${config.sops.placeholder."tokens/gh-ns-test"}" "gitlab.com=${config.sops.placeholder."tokens/gitlab-ns"}" "gitlab.com=${config.sops.placeholder."tokens/gitlab-fa"}"
    '';
  };

  environment.systemPackages = with pkgs; [
    apparmor-bin-utils # unneeded?
    apparmor-pam # unneeded?
    apparmor-parser # unneeded?
    apparmor-profiles # unneeded?
    apparmor-utils # unneeded?
    libapparmor # unneeded?
    
    age
    sops

    libnfs
    nfs-utils    # Shells and Shell Enhancements
    bash # Bourne Again SHell
    bash-completion # Bash command completion
    zsh # Z shell
    zsh-autocomplete # Zsh command autocompletion
    blesh # Bash autocompleter

    # Core Utilities
    coreutils-full # GNU core utilities
    util-linux # Miscellaneous system utilities

    # Networking Tools
    curl # Command line tool for transferring data with URLs
    nftables # Netfilter tables for packet filtering
    nettools # Network tools like ifconfig, netstat, etc.
    wget # Network downloader
    wireguard-tools # Tools for the WireGuard VPN
    bridge-utils # Utilities for configuring network bridges

    # System Monitoring and Management
    lm_sensors # Hardware monitoring
    kexec-tools # Tools for loading a new kernel
    linuxHeaders # Linux kernel headers
    rng-tools # Random number generator tools
    smartmontools # Control and monitor storage systems using S.M.A.R.T.
    rsync # Fast, versatile, remote (and local) file-copying tool
    tree # Display directories as trees
    btop # Resource monitor

    # Multimedia Tools
    ffmpeg # Multimedia framework for handling video, audio, and other multimedia files

    # Text Editors
    micro # Terminal-based text editor

    # System Information
    # fastfetch # Neofetch-like tool for displaying system information

    # Development Tools
    automake # Tool for automatically generating Makefile.in files
    clang # C language family frontend for LLVM
    cmake # Cross-platform, open-source build system
    autoconf # Generates configuration scripts
    git # Version control system, required by flakes
    pipx # Install and run Python applications in isolated environments
    # poetry # Python dependency management and packaging

    # Terminal Multiplexers and Plugins
    tmux # Terminal multiplexer
    tmuxPlugins.dracula # Dracula theme for tmux
    tmuxPlugins.gruvbox # Gruvbox theme for tmux

    # Miscellaneous Tools
    eza # Modern replacement for 'ls'
    p7zip # File archiver with high compression ratio
    realmd # Discover and join identity domains
    xclip # Command line interface to the X11 clipboard
    bat # Cat clone with syntax highlighting and Git integration
    direnv # Environment switcher for the shell
    fzf # Command-line fuzzy finder
    nix-direnv # Integration of direnv with Nix
    zoxide # Smarter cd command
    sbctl # Secure Boot key manager
    colmena # Remote management tool
    lsof # List open files
    envsubst

    baobab # Disk usage analyzer
    # restic
    # deja-dup
  ];

  fonts.packages = with pkgs; [
    google-fonts # Collection of Google Fonts
    ibm-plex # IBM Plex font family
    meslo-lgs-nf # Meslo Nerd Font patched for Powerlevel10k
    nerd-fonts.ubuntu
    nerd-fonts.inconsolata
    nerd-fonts.mononoki
    nerd-fonts.fira-code
    nerd-fonts.tinos
    noto-fonts
    noto-fonts-color-emoji
  ];
}
