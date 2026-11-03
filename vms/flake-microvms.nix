{
  inputs,
  system,
  VARS,
  consts,
  ...
}:
let
  inherit (inputs) nixpkgs;
  microvmModule = inputs.microvm.nixosModules.microvm;

  fromInputsOverlays = {
    imports = [ ../modules/core/overlays.nix ];

    sys.overlays.fromInputs = {
      nixpkgs-unstable = [
        "gitea"
        "firefly-iii"
        "firefly-iii-data-importer"
        "pocket-id"
        "seerr"
        "jellyfin"
        "jellyfin-web"
        "jellyfin-ffmpeg"
      ];

      nixpkgs-master = [
        "immich"
        "immich-cli"
        "immich-machine-learning"
      ];
    };
  };

  /*
    paperlessBuildWorkaround = {
      nixpkgs.overlays = [
        (_final: prev: {
          "paperless-ngx" = prev."paperless-ngx".overrideAttrs (_old: {
            doCheck = false;
            doInstallCheck = false;
          });
        })
      ];
    };
  */

  mkMicrovm =
    modules:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        fromInputsOverlays
        # ../modules/core/nixpkgs-module-overrides.nix
        microvmModule
      ]
      ++ modules;

      specialArgs = {
        inherit inputs system VARS;
        inherit consts;
        jellyfinSettings = import ./jellyfin-settings.nix;
      };
    };
in
{
  adguard-vm = mkMicrovm [
    ./adguard.nix
  ];

  actual-vm = mkMicrovm [
    ./actual.nix
  ];

  searx-vm = mkMicrovm [
    ./searx.nix
  ];

  overseerr-vm = mkMicrovm [
    ./overseerr.nix
  ];

  ombi-vm = mkMicrovm [
    ./ombi.nix
  ];

  tautulli-vm = mkMicrovm [
    ./tautulli.nix
  ];

  gitea-vm = mkMicrovm [
    ./gitea.nix
  ];

  sonarr-vm = mkMicrovm [
    ./sonarr.nix
  ];

  radarr-vm = mkMicrovm [
    ./radarr.nix
  ];

  prowlarr-vm = mkMicrovm [
    ./prowlarr.nix
  ];

  bazarr-vm = mkMicrovm [
    ./bazarr.nix
  ];

  readarr-vm = mkMicrovm [
    ./readarr.nix
  ];

  lidarr-vm = mkMicrovm [
    ./lidarr.nix
  ];

  qbittorrent-vm = mkMicrovm [
    ./qbittorrent.nix
  ];

  cross-seed-vm = mkMicrovm [
    ./cross-seed.nix
  ];

  sabnzbd-vm = mkMicrovm [
    ./sabnzbd.nix
  ];

  firefox-vm = mkMicrovm [
    ./firefox.nix
  ];

  brave-vm = mkMicrovm [
    ./brave.nix
  ];

  wireguard-vm = mkMicrovm [
    ./wireguard.nix
  ];

  matrix-synapse-vm = mkMicrovm [
    ./matrix-synapse.nix
    { services.mautrix-whatsapp.enable = true; }
  ];

  paperless-vm = mkMicrovm [
    # paperlessBuildWorkaround
    ./paperless.nix
  ];

  firefly-vm = mkMicrovm [
    ./firefly.nix
  ];

  firefly-importer-vm = mkMicrovm [
    ./firefly-importer.nix
  ];

  immich-vm = mkMicrovm [
    ./immich.nix
  ];

  jellyfin-vm = mkMicrovm [
    ./jellyfin.nix
  ];

  mealie-vm = mkMicrovm [
    ./mealie.nix
  ];

  trigger-vm = mkMicrovm [
    ./trigger.nix
  ];

  pocket-id-vm = mkMicrovm [
    ./pocket-id.nix
  ];
}
