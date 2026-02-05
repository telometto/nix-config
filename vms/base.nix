{
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../modules/security/secrets.nix
  ];

  # Minimal hardened configuration for service VMs
  # Import this module for any MicroVM that should have minimal attack surface
  boot = {
    kernelPackages = lib.mkDefault pkgs.linuxPackages_hardened;

    kernelParams = [
      "quiet"
      "mitigations=auto"
    ];

    kernel.sysctl = {
      # Network security: enable reverse path filtering to prevent IP spoofing
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;

      # Ignore ICMP broadcast requests to prevent Smurf attacks
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

      # Disable source routing to prevent packet routing manipulation
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;

      # Disable ICMP redirects to prevent routing table manipulation
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;

      # Disable core dumps to prevent sensitive data leaks
      "kernel.core_pattern" = "|/bin/false";

      # Restrict dmesg access to privileged users only
      "kernel.dmesg_restrict" = 1;

      # Restrict access to kernel pointers in /proc
      "kernel.kptr_restrict" = 2;
    };

    blacklistedKernelModules = [
      "bluetooth"
      "btusb"
      "uvcvideo"
    ];
  };

  services = {
    udisks2.enable = false;

    journald.extraConfig = ''
      SystemMaxUse=100M
      RuntimeMaxUse=50M
    '';

    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;
        AllowAgentForwarding = false;
        AllowTcpForwarding = false;
        MaxAuthTries = 3;
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
      };
    };
  };

  systemd.coredump.enable = false;

  security = {
    sudo.wheelNeedsPassword = true;

    apparmor = {
      enable = lib.mkDefault true;
      enableCache = false;
      killUnconfinedConfinables = lib.mkDefault true;

      packages = [
        pkgs.apparmor-profiles
      ];
    };

    pam.loginLimits = [
      {
        domain = "*";
        type = "hard";
        item = "core";
        value = "0";
      }
    ];
  };

  networking.firewall = {
    enable = lib.mkDefault true;
    allowPing = lib.mkDefault false;
    logRefusedConnections = false;
  };

  environment.etc."profile.local".text = ''
    umask 027
  '';

  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  documentation = {
    enable = true;
    doc.enable = false;
    man.enable = true;
    info.enable = false;
    nixos.enable = false;
  };

  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
  ];
}
