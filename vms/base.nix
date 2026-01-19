{
  lib,
  config,
  pkgs,
  ...
}:
{
  # Minimal hardened configuration for service VMs
  # Import this module for any MicroVM that should have minimal attack surface

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_hardened;

  # Minimal kernel parameters
  boot.kernelParams = [
    "quiet"
    "mitigations=auto"
  ];

  # Disable unnecessary services
  services = {
    udisks2.enable = false;

    # Reduced journal size
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
      };
    };
  };

  # Minimal hardening
  security = {
    sudo.wheelNeedsPassword = true;
    apparmor.enable = lib.mkDefault true;
  };

  # Minimal timezone and locale
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

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

  # Minimal packages for debugging
  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
  ];
}
