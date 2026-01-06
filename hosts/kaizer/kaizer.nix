{
  lib,
  pkgs,
  config,
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

    boot.lanzaboote.enable = lib.mkForce false;

    overlays.fromInputs = {
      # nixpkgs-unstable = [ "firefox" "discord" ];
      nixpkgs-stable = [ "vesktop" ];
    };

    hardware.nvidia = {
      enable = true;

      open = true;

      # Enable if suspend/resume issues occur (experimental)
      # powerManagement.enable = true;

      # Ampere supports fine-grained power management
      # Uncomment if you want the GPU to power down when idle
      # powerManagement.finegrained = false;
    };

    # programs = {
    #   nix-ld.enable = true;
    #   python-venv.enable = false;
    #   gnupg.enable = true;
    #   mtr.enable = true;
    # };

    # # Pull specific packages from different nixpkgs inputs
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
        interface = "enp42s0";
        openFirewall = true;
      };

      printing.enable = lib.mkForce false;
    };
  };

  services.tailscale.authKeyFile = lib.mkForce config.telometto.secrets.kaizerTsKey;

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

    graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };
  };

  environment.systemPackages = with pkgs; [
    temurin-jre-bin-21
    temurin-jre-bin-17
    temurin-jre-bin-8
    glfw

    # Alternative: prismlauncher if Titan doesn't work well
    # prismlauncher
  ];

  system.stateVersion = "24.11";
}
