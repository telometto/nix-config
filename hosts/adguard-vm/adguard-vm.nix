{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/profiles/headless.nix")
  ];

  # VM-specific configuration
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  # Minimal filesystem
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  # Minimal networking
  networking = {
    hostName = "adguard-vm";
    useDHCP = false;
    interfaces.eth0.useDHCP = true;

    # Open required ports
    firewall = {
      enable = true;
      allowedTCPPorts = [
        53 # DNS
        80 # AdGuard web UI
        443 # HTTPS (if needed)
        3000 # Initial setup port
      ];
      allowedUDPPorts = [
        53 # DNS
      ];
    };
  };

  # Enable AdGuard Home
  sys.services.adguardhome = {
    enable = true;
    openFirewall = false; # We handle firewall manually above
  };

  # Minimal system configuration
  system.stateVersion = "24.11";

  # SSH for management
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Create admin user
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here
    ];
  };

  # Minimal hardening
  security = {
    sudo.wheelNeedsPassword = true;
    apparmor.enable = true;
  };

  # Use hardened kernel
  boot.kernelPackages = pkgs.linuxPackages_hardened;

  # No GUI
  environment.noXlibs = true;

  # Minimal packages
  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
  ];

  # Automatic updates (optional - can be disabled for more control)
  system.autoUpgrade = {
    enable = false;
  };

  # Reduce memory usage
  services = {
    # Disable unnecessary services
    udisks2.enable = false;

    # Journal settings for lower disk usage
    journald.extraConfig = ''
      SystemMaxUse=100M
      RuntimeMaxUse=50M
    '';
  };

  # Optimize for VM
  boot.kernelParams = [
    "quiet"
    "mitigations=auto"
  ];

  # Reduce boot time
  systemd.services = {
    NetworkManager-wait-online.enable = false;
  };

  # Timezone and locale (minimal)
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix settings
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # Minimal documentation
  documentation = {
    enable = true;
    doc.enable = false;
    man.enable = true;
    info.enable = false;
    nixos.enable = false;
  };
}
