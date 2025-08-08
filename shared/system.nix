# Shared system configuration applied to all devices
{ config, lib, pkgs, VARS, inputs, mylib, ... }:

let
  commonPackages =
    import ./system-packages.nix { inherit config lib pkgs VARS; };
  LANG_NO = "nb_NO.UTF-8";
  MEM_MAX = 7500000;
in
{

  imports = [
    # inputs.agenix.nixosModules.default  # Not available in current inputs
    inputs.sops-nix.nixosModules.sops
    inputs.lanzaboote.nixosModules.lanzaboote
    # inputs.microvm.nixosModules.host # For hosts (import per-host when needed)

    # Profiles (desktop/laptop/server) are imported in hosts
  ];

  # Nix settings and optimization
  nix = {
    settings = {
      trusted-users = [ "root" "@wheel" ];
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      download-buffer-size = 536870912; # 512MB
    };

    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 7d";
    };

    optimise = {
      automatic = true;
      dates = [ "02:00" ];
    };

    extraOptions = ''
      !include ${config.sops.templates."access-tokens".path}
    '';
  };

  # Boot configuration
  boot = {
    supportedFilesystems = [ "nfs" ]
      ++ lib.optionals (mylib.isServer config.networking.hostName) [ "zfs" ]
      ++ lib.optionals
      (mylib.isDesktop config.networking.hostName
        || mylib.isLaptop config.networking.hostName) [ "btrfs" ];

    loader = {
      systemd-boot.enable = lib.mkForce false; # required for lanzaboote
      efi.canTouchEfiVariables = true;
      systemd-boot.configurationLimit = 3;
      timeout = 0;
    };

    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };

    kernel.sysctl = {
      "net.core.wmem_max" = MEM_MAX;
      "net.core.rmem_max" = MEM_MAX;
    } // lib.optionalAttrs (mylib.isServer config.networking.hostName) {
      "net.ipv4.conf.all.src_valid_mark" = 1;
    };

    initrd = {
      enable = true;
      verbose = false;
      systemd.enable = lib.mkDefault true;
      supportedFilesystems.nfs = true;
      systemd.emergencyAccess =
        config.users.users.${VARS.users.admin.user}.hashedPassword;
    } // lib.optionalAttrs (mylib.isServer config.networking.hostName) {
      supportedFilesystems.zfs = true;
    } // lib.optionalAttrs
      (mylib.isDesktop config.networking.hostName
        || mylib.isLaptop config.networking.hostName)
      {
        supportedFilesystems.btrfs = true;
      };

    plymouth = {
      enable = true;
      theme = "spinner";
    };

    consoleLogLevel = 0;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];

    zfs = mylib.mkServerConfig config.networking.hostName {
      forceImportAll = true;
      requestEncryptionCredentials = true;
      devNodes = "/dev/disk/by-id";
    };
  };

  environment = {
    variables = {
      EDITOR = "micro";
      SSH_ASKPASS_REQUIRE = "prefer";
    } // lib.optionalAttrs (mylib.isServer config.networking.hostName) {
      KUBECONFIG = "/home/${VARS.users.admin.user}/.kube/config";
    };

    systemPackages = commonPackages.base
      ++ lib.optionals
      (mylib.isDesktop config.networking.hostName
        || mylib.isLaptop config.networking.hostName)
      commonPackages.desktop
      ++ lib.optionals (mylib.isServer config.networking.hostName)
      commonPackages.server;
  };

  # Networking base configuration
  networking = {
    firewall = rec {
      enable = lib.mkDefault true;
      allowedTCPPorts =
        lib.optionals (mylib.isServer config.networking.hostName) [
          80
          443
          111
          2049
          20048
          28981
          6443
        ] ++ lib.optionals
          (mylib.isDesktop config.networking.hostName
          || mylib.isLaptop config.networking.hostName) [
          2049
          4000
          4001
          4002
          20048
        ];

      allowedUDPPorts = allowedTCPPorts;

      allowedTCPPortRanges = lib.optionals
        (mylib.isDesktop config.networking.hostName
          || mylib.isLaptop config.networking.hostName) [{ from = 1714; to = 1764; }]
      ++ lib.optionals (mylib.isServer config.networking.hostName) [{ from = 4000; to = 4002; }];

      allowedUDPPortRanges = allowedTCPPortRanges;
    };

    networkmanager.enable = mylib.isDesktop config.networking.hostName
      || mylib.isLaptop config.networking.hostName;
    wireless.enable = lib.mkDefault false;
    useNetworkd = lib.mkDefault false; # server overrides per-host if needed
    nftables.enable = lib.mkDefault false;
  };

  time.timeZone = "Europe/Oslo";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    glibcLocales = pkgs.glibcLocales.override { allLocales = true; };
    extraLocaleSettings = {
      LC_ADDRESS = LANG_NO;
      LC_IDENTIFICATION = LANG_NO;
      LC_MEASUREMENT = LANG_NO;
      LC_MONETARY = LANG_NO;
      LC_NAME = LANG_NO;
      LC_NUMERIC = LANG_NO;
      LC_PAPER = LANG_NO;
      LC_TELEPHONE = LANG_NO;
      LC_TIME = LANG_NO;
    };
  };

  console.useXkbConfig = true;

  services = {
    fwupd.enable = true;
    zram-generator.enable = true;

    # Desktop/laptop printing default
    printing.enable = lib.mkDefault (mylib.isDesktop config.networking.hostName
      || mylib.isLaptop config.networking.hostName);

    xserver.xkb = {
      layout = "no";
      variant = "";
    };

    networkd-dispatcher = {
      enable = true;
      rules."50-tailscale" = {
        onState = [ "routable" ];
        script = ''
          ${lib.getExe pkgs.ethtool} -K eth0 rx-udp-gro-forwarding on rx-gro-list off
        '';
      };
    };

    openssh = {
      enable = true;
      openFirewall = true;
      banner = ''
        ╔════════════════════════════════════════════════════╗
        ║                                                    ║
        ║  WARNING: This system is restricted to authorized  ║
        ║  users only! All activities are monitored and      ║
        ║  recorded. Unauthorized access is strictly         ║
        ║  prohibited and will result in legal action.       ║
        ║                                                    ║
        ╚════════════════════════════════════════════════════╝
      '';
      settings = {
        X11Forwarding = false;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        UsePAM = true;
      };
    };

    tailscale = {
      enable = true;
      openFirewall = true;
      authKeyFile = config.sops.secrets."general/tsKeyFilePath".path;
      authKeyParameters = { preauthorized = true; ephemeral = false; };
      extraUpFlags = [ "--reset" "--ssh" ]
        ++ lib.optionals (mylib.isServer config.networking.hostName) [ "--advertise-routes=192.168.2.0/24" ]
        ++ lib.optionals (mylib.isLaptop config.networking.hostName) [ "--accept-routes" ];
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

    resolved = {
      enable = true;
      dnssec = "allow-downgrade";
      dnsovertls = "opportunistic";
      llmnr = "true";
    };

    fstrim.enable = true;

    devmon.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;
    rpcbind.enable = lib.mkOptionDefault true;

    # Server desktop-specific ZFS auto tasks moved to server profile

    # NFS: restrict shared export to server only; desktop export lives in devices/snowfall
    nfs.server = mylib.mkModule {
      condition = mylib.isServer config.networking.hostName;
      config = {
        enable = true;
        lockdPort = 4001;
        mountdPort = 4002;
        statdPort = 4000;
        exports = ''
          /rpool/enc/transfers 192.168.2.0/24(rw,sync,nohide,no_subtree_check)
        '';
      };
    };
  };

  security = {
    apparmor.enable = true;
    polkit.enable = true;
    tpm2.enable = true;
    rtkit.enable = mylib.isDesktop config.networking.hostName || mylib.isLaptop config.networking.hostName;

    pam.services = {
      login = { enableAppArmor = true; gnupg.enable = true; };
      # sddm-specific hardening lives in the KDE module
    };
  };

  programs = {
    mtr.enable = true;

    gnupg.agent.enable = false; # prefer Home Manager gpg-agent

    ssh = {
      startAgent = lib.mkDefault false; # prefer Home Manager ssh-agent
      enableAskPassword = true;
      forwardX11 = false;
      setXAuthLocation = false;
    };

    zsh.enable = true;

    gnome-disks = mylib.mkModule {
      condition = mylib.isDesktop config.networking.hostName || mylib.isLaptop config.networking.hostName;
      config.enable = true;
    };

    gnome-terminal = mylib.mkModule {
      condition = mylib.isDesktop config.networking.hostName || mylib.isLaptop config.networking.hostName;
      config.enable = false;
    };

    light.brightnessKeys = mylib.mkLaptopConfig config.networking.hostName { enable = true; };

    seahorse = mylib.mkModule {
      condition = mylib.isLaptop config.networking.hostName;
      config.enable = true;
    };
  };

  # Virtualisation consolidated into shared/virtualisation/podman.nix and profiles

  # System auto-upgrade
  system.autoUpgrade = {
    enable = true;
    flake = "github:telometto/nix-config";
    operation = "boot";
    dates = "weekly";
    rebootWindow = { lower = "00:00"; upper = "02:30"; };
    persistent = true;
    allowReboot = true;
    fixedRandomDelay = true;
    randomizedDelaySec = "20min";
  };

  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    secrets = {
      "general/tsKeyFilePath" = { };
      "general/paperlessKeyFilePath" = { };
      "general/searxSecretKey" = { };
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

  # Use zram-generator only (disable legacy zramSwap)
  zramSwap.enable = lib.mkForce false;

  nixpkgs.config.allowUnfree = lib.mkDefault true;
}
