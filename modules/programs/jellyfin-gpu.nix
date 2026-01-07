{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.sys.programs.jellyfinGpu;
  jellyfinEnabled = config.sys.services.jellyfin.enable or false;
in
{
  options.sys.programs.jellyfinGpu = {
    enable = lib.mkEnableOption "Jellyfin VAAPI/Intel GPU support packages";

    driver = lib.mkOption {
      type = lib.types.enum [
        "iHD"
        "i965"
      ];
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
      type = lib.types.enum [
        "newer"
        "older"
      ];
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
    {
      sys.programs.jellyfinGpu.enable = lib.mkDefault (
        config.sys.services.jellyfin.enable or false
      );
    }

    (lib.mkIf cfg.enable {
      hardware.graphics = {
        enable = lib.mkDefault true;
        extraPackages =
          with pkgs;
          [
            intel-ocl

            intel-media-driver
            (intel-vaapi-driver.override { enableHybridCodec = true; })
            libva-vdpau-driver

          ]
          ++ lib.optionals (cfg.intelGeneration == "newer") [
            intel-compute-runtime
            vpl-gpu-rt
          ]
          ++ lib.optionals (cfg.intelGeneration == "older") [
            intel-compute-runtime-legacy1
          ];
      };

      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = lib.mkForce cfg.driver;
      };

      systemd.services.jellyfin.environment = {
        LIBVA_DRIVER_NAME = cfg.driver;
      };

      hardware.enableAllFirmware = lib.mkIf cfg.enableAllFirmware (lib.mkDefault true);
    })

    (lib.mkIf (cfg.enable && jellyfinEnabled) {
      users.users.${config.sys.services.jellyfin.user or "jellyfin"}.extraGroups = [
        "video"
        "render"
      ];
    })
  ];
}
