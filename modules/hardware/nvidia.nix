{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.hardware.nvidia;
in
{
  options.telometto.hardware.nvidia = {
    enable = lib.mkEnableOption "NVIDIA GPU support with proprietary drivers";

    package = lib.mkOption {
      type = lib.types.package;
      default = config.boot.kernelPackages.nvidiaPackages.latest;
      description = "NVIDIA driver package to use";
    };

    modesetting = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable modesetting (required for Wayland)";
    };

    powerManagement = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable experimental power management (may cause sleep/suspend issues)";
      };

      finegrained = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable fine-grained power management (Turing or newer)";
      };
    };

    open = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Use open-source NVIDIA kernel module (Turing or newer).
        Recommended for RTX 20 series and newer (Ampere, Ada, Hopper).
        Required for driver version 560+.
      '';
    };

    nvidiaSettings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable nvidia-settings utility";
    };

    containerToolkit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable NVIDIA Container Toolkit for Docker/Podman GPU support";
    };

    cudaSupport = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable CUDA support in nixpkgs";
    };

    fbdev = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable fbdev for nvidia-drm";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = lib.mkIf cfg.fbdev [ "nvidia-drm.fbdev=1" ];

    hardware = {
      nvidia-container-toolkit.enable = lib.mkIf cfg.containerToolkit true;

      graphics = {
        enable = lib.mkDefault true;
        enable32Bit = lib.mkDefault true;
      };

      nvidia = {
        modesetting.enable = cfg.modesetting;

        powerManagement = {
          inherit (cfg.powerManagement) enable finegrained;
        };

        inherit (cfg) open nvidiaSettings package;
      };
    };

    nixpkgs.config.cudaSupport = cfg.cudaSupport;

    services.xserver.videoDrivers = [ "nvidia" ];
  };
}
