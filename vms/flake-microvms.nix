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

  fromInputsOverlays = {
    imports = [ ../modules/core/overlays.nix ];

    sys.overlays.fromInputs = {
      nixpkgs-unstable = [
        "libreoffice"
        "libreoffice-still"
      ];
      # nixpkgs-stable = [ "cloud-hypervisor" ];
    };
  };

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

  mkMicrovm =
    modules:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ fromInputsOverlays ] ++ modules;

      specialArgs = { inherit inputs system VARS; };
    };
in
{
  # adguard-vm = mkMicrovm [
  #   microvmModule
  #   ./adguard.nix
  #   sopsModule
  # ];

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

  paperless-vm = mkMicrovm [
    microvmModule
    sopsModule
    paperlessBuildWorkaround
    ./paperless.nix
  ];

  firefly-vm = mkMicrovm [
    microvmModule
    sopsModule
    ./firefly.nix
  ];
}
