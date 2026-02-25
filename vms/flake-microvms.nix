{
  inputs,
  system,
  VARS,
  ...
}:
let
  inherit (inputs) nixpkgs;
  microvmModule = inputs.microvm.nixosModules.microvm;
  sopsModule = inputs.sops-nix.nixosModules.sops;

  # TODO: Remove once microvm.nix adds format=raw to cloud-hypervisor disk args
  # cloud-hypervisor v51.0 blocks sector-0 writes for autodetected raw images
  # (security fix PR #7728), breaking all MicroVM volume mounts
  stablePkgs = import inputs.nixpkgs-stable { inherit system; };
  pinnedOverlays = {
    nixpkgs.overlays = [
      (_final: _prev: {
        inherit (stablePkgs) cloud-hypervisor;
      })
    ];
  };

  mkMicrovm =
    modules:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ pinnedOverlays ] ++ modules;

      specialArgs = { inherit inputs system VARS; };
    };
in
{
  adguard-vm = mkMicrovm [
    microvmModule
    ./adguard.nix
    sopsModule
  ];

  actual-vm = mkMicrovm [
    microvmModule
    ./actual.nix
  ];

  searx-vm = mkMicrovm [
    microvmModule
    ./searx.nix
  ];

  overseerr-vm = mkMicrovm [
    microvmModule
    ./overseerr.nix
  ];

  # scrutiny-vm = mkMicrovm [
  #   microvmModule
  #   ./scrutiny.nix
  # ];

  ombi-vm = mkMicrovm [
    microvmModule
    ./ombi.nix
  ];

  tautulli-vm = mkMicrovm [
    microvmModule
    ./tautulli.nix
  ];

  gitea-vm = mkMicrovm [
    microvmModule
    ./gitea.nix
  ];

  sonarr-vm = mkMicrovm [
    microvmModule
    ./sonarr.nix
  ];

  radarr-vm = mkMicrovm [
    microvmModule
    ./radarr.nix
  ];

  prowlarr-vm = mkMicrovm [
    microvmModule
    ./prowlarr.nix
  ];

  bazarr-vm = mkMicrovm [
    microvmModule
    ./bazarr.nix
  ];

  readarr-vm = mkMicrovm [
    microvmModule
    ./readarr.nix
  ];

  lidarr-vm = mkMicrovm [
    microvmModule
    ./lidarr.nix
  ];

  qbittorrent-vm = mkMicrovm [
    microvmModule
    ./qbittorrent.nix
  ];

  sabnzbd-vm = mkMicrovm [
    microvmModule
    ./sabnzbd.nix
  ];

  firefox-vm = mkMicrovm [
    microvmModule
    ./firefox.nix
  ];

  brave-vm = mkMicrovm [
    microvmModule
    ./brave.nix
  ];

  wireguard-vm = mkMicrovm [
    microvmModule
    ./wireguard.nix
  ];

  matrix-synapse-vm = mkMicrovm [
    microvmModule
    sopsModule
    ./matrix-synapse.nix
  ];
}
