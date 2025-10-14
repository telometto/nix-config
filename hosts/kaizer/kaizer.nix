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
  };

  telometto = {
    role.desktop.enable = true;

    desktop.flavor = "gnome";

    # Disabled secure boot (lanzaboote) for now
    boot.lanzaboote.enable = lib.mkDefault false;

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

        # Override to preserve Luke's existing Tailscale authentication
        # Don't set authKeyFile - this allows the existing connection to persist
        settings = {
          authKeyFile = lib.mkForce null;
        };
      };

      # Disable printing as in nix-conf
      printing.enable = lib.mkForce false;
    };
  };

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
  };

  system.stateVersion = "24.11";
}
