{ lib, pkgs, config, ... }:
let
  cfg = config.telometto.programs.jellyfinGpu;
  jellyfinEnabled = config.telometto.services.jellyfin.enable or false;
in {
  options.telometto.programs.jellyfinGpu.enable =
    lib.mkEnableOption "Jellyfin VAAPI/Intel GPU support packages";

  config = lib.mkMerge [
    # Follow Jellyfin service by default (host can still override explicitly)
    {
      telometto.programs.jellyfinGpu.enable =
        lib.mkDefault (config.telometto.services.jellyfin.enable or false);
    }

    (lib.mkIf cfg.enable {
      # 1. Enable graphics stack and VAAPI userspace
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          # Use the intel-vaapi-driver (aka vaapiIntel) with hybrid codecs enabled, but without mutating the global package set
          (vaapiIntel.override { enableHybridCodec = true; })
          vaapiVdpau
          intel-compute-runtime
          vpl-gpu-rt
          # intel-media-sdk # Deprecated due to security issues
        ];
      };
    })

    # 2. Ensure Jellyfin service account can access GPU devices when the service is enabled
    # Avoid creating the user when the service is disabled
    # (the upstream service module defines the user; we just add extra groups)
    (lib.mkIf (cfg.enable && jellyfinEnabled) {
      users.users.jellyfin.extraGroups = [ "video" "render" ];
    })
  ];
}
