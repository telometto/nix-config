{
  lib,
  pkgs,
  config,
  VARS,
  inputs,
  ...
}:
let
  LOCALE = "it_IT.UTF-8";
in
{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ];

  networking = {
    hostName = lib.mkForce "kaizer";
    hostId = lib.mkForce "632f97e1";

    firewall = rec {
      enable = true;

      allowedTCPPorts = [ ];
      allowedUDPPorts = allowedTCPPorts;

      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
  };

  telometto = {
    role.desktop.enable = true;

    desktop.flavor = "kde";

    users = {
      gianluca.enable = true;
      frankie.enable = true;
    };

    # Disabled secure boot (lanzaboote) for now
    boot.lanzaboote.enable = lib.mkForce false;

    # Enable Nvidia hardware support (RTX 3070 - Ampere architecture)
    hardware.nvidia = {
      enable = true;

      # RTX 3070 (Ampere) supports open-source kernel modules
      # Recommended by NVIDIA for better performance and stability
      open = true;

      # Enable if suspend/resume issues occur (experimental)
      # powerManagement.enable = true;

      # Ampere supports fine-grained power management
      # Uncomment if you want the GPU to power down when idle
      # powerManagement.finegrained = false;
    };

    # Enable Python venv support
    programs = {
      nix-ld.enable = true;
      python-venv.enable = false;
      gnupg.enable = true; # Enable GPG with SSH support
      mtr.enable = true; # Enable mtr as in nix-conf
    };

    # Pull specific packages from different nixpkgs inputs
    # overlays.fromInputs = {
    #   nixpkgs-unstable = [ "firefox" "discord" ];
    #   nixpkgs-stable = [ "thunderbird" ];
    # };
    #
    # Add custom overlays
    # overlays.custom = [
    #   (final: prev: {
    #     firefox = prev.firefox.override {
    #       enablePlasmaBrowserIntegration = true;
    #     };
    #   })
    # ];

    services = {
      tailscale = {
        interface = "enp42s0"; # Update based on actual interface from hardware-configuration
        openFirewall = true;
      };

      # Disable printing as in nix-conf
      printing.enable = lib.mkForce false;
    };
  };

  # Override Tailscale to preserve Luke's existing authentication
  # Don't set authKeyFile - this allows the existing connection to persist
  services.tailscale.authKeyFile = lib.mkForce null;

  # Locale overrides for Italian with Oslo timezone and Norwegian keyboard
  i18n.extraLocaleSettings = lib.mkForce (
    lib.genAttrs [
      "LC_ADDRESS"
      "LC_IDENTIFICATION"
      "LC_MEASUREMENT"
      "LC_MONETARY"
      "LC_NAME"
      "LC_NUMERIC"
      "LC_PAPER"
      "LC_TELEPHONE"
      "LC_TIME"
    ] (_: LOCALE)
  );

  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault true;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    # Enable OpenGL for Minecraft
    graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };
  };

  # Minecraft/Titan Launcher support
  # Install Java runtimes needed for different Minecraft versions
  environment.systemPackages = with pkgs; [
    # Java runtimes for different Minecraft versions
    temurin-jre-bin-21 # For Minecraft >= 1.20.5 (latest)
    temurin-jre-bin-17 # For Minecraft >= 1.18
    temurin-jre-bin-8 # For Minecraft < 1.17
    glfw

    # Alternative: prismlauncher if Titan doesn't work well
    # prismlauncher
  ];

  system.stateVersion = "24.11";
}
