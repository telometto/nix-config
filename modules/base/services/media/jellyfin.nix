{ config, lib, pkgs, ... }:

{
  services.jellyfin = {
    enable = true;

    openFirewall = true;

    # user = ""; # Default: "jellyfin"
    # group = ""; # Default: "jellyfin"

    # dataDir = "/var/lib/jellyfin";
    # logDir = "/var/log/jellyfin"; # Default: "${cfg.dataDir}/log"
    # cacheDir = "/var/cache/jellyfin"; # Default: "/var/cache/jellyfin"
    # configDir = "/etc/jellyfin"; # Default: "${cfg.dataDir}/config"
  };

    nixpkgs.overlays = with pkgs; [
    (
      final: prev:
        {
          jellyfin-web = prev.jellyfin-web.overrideAttrs (finalAttrs: previousAttrs: {
            installPhase = ''
              runHook preInstall

              # this is the important line
              sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html

              mkdir -p $out/share
              cp -a dist $out/share/jellyfin-web

              runHook postInstall
            '';
          });
        }
    )
  ];

  # 1. enable vaapi on OS-level
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      vaapiVdpau
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      vpl-gpu-rt # QSV on 11th gen or newer
      intel-media-sdk # QSV up to 11th gen
    ];
  };

  environment.systemPackages = with pkgs; [
    jellyfin # Media server
    jellyfin-ffmpeg # Conversion tools
    jellyfin-web # Web client
    jellyseerr # Fork of Overseerr
  ];
}