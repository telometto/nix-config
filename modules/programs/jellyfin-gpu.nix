{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.telometto.programs.jellyfinGpu;
  jellyfinEnabled = config.telometto.services.jellyfin.enable or false;
in
{
  options.telometto.programs.jellyfinGpu = {
    enable = lib.mkEnableOption "Jellyfin VAAPI/Intel GPU support packages";

    driver = lib.mkOption {
      type = lib.types.enum [ "iHD" "i965" ];
      default = "iHD";
      description = ''
        VAAPI driver to use for hardware acceleration.
        - iHD: For newer Intel processors (Broadwell and higher, ca. 2014+). Uses intel-media-driver.
        - i965: For older Intel processors (pre-Broadwell). Uses intel-vaapi-driver.
      '';
    };

    enableAllFirmware = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable all firmware. Required for some Intel CPUs (e.g., N100) to properly load GuC firmware.
        Set to false if you want to manage firmware manually.
      '';
    };

    intelGeneration = lib.mkOption {
      type = lib.types.enum [ "newer" "older" ];
      default = "newer";
      description = ''
        Intel CPU generation for package selection:
        - newer: 11th gen or newer (includes vpl-gpu-rt, intel-compute-runtime)
        - older: Older generations (includes intel-compute-runtime-legacy1)
        Note: intel-media-sdk is deprecated and not included.
      '';
    };
  };

  config = lib.mkMerge [
    # Follow Jellyfin service by default (host can still override explicitly)
    {
      telometto.programs.jellyfinGpu.enable = lib.mkDefault (
        config.telometto.services.jellyfin.enable or false
      );
    }

    (lib.mkIf cfg.enable {
      # 1. Enable graphics stack and VAAPI userspace with comprehensive Intel support
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs;
          [
            intel-ocl # Generic OpenCL support for all processors

            # VAAPI drivers based on processor generation
            intel-media-driver # For newer processors (Broadwell+) with iHD
            (intel-vaapi-driver.override { enableHybridCodec = true; }) # For older processors with i965
            libva-vdpau-driver # aka vaapiVdpau

            # Compute runtime based on generation
          ]
          ++ lib.optionals (cfg.intelGeneration == "newer") [
            intel-compute-runtime # For 13th gen and higher
            vpl-gpu-rt # For 11th gen or newer
          ]
          ++ lib.optionals (cfg.intelGeneration == "older") [
            intel-compute-runtime-legacy1 # For older processors
          ];
      };

      # 2. Set LIBVA_DRIVER_NAME environment variable for the system and Jellyfin service
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = lib.mkForce cfg.driver;
      };

      # 3. Set LIBVA_DRIVER_NAME for the Jellyfin systemd service
      systemd.services.jellyfin.environment = {
        LIBVA_DRIVER_NAME = cfg.driver;
      };

      # 4. Enable all firmware if requested (needed for GuC firmware on some Intel CPUs)
      hardware.enableAllFirmware = lib.mkIf cfg.enableAllFirmware true;
    })

    # 5. Ensure Jellyfin service account can access GPU devices when the service is enabled
    # Avoid creating the user when the service is disabled
    # (the upstream service module defines the user; we just add extra groups)
    (lib.mkIf (cfg.enable && jellyfinEnabled) {
      users.users.${config.telometto.services.jellyfin.user or "jellyfin"}.extraGroups = [
        "video"
        "render"
      ];
    })
  ];
}
