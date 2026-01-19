{
  description = "NixOS configuration with auto-imported modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable-latest.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-secrets = {
      url = "git+ssh://git@github.com/telometto/nix-secrets.git";
      flake = true;
    };

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    nix-colors.url = "github:misterio77/nix-colors";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-secrets,
      ...
    }:
    let
      system = "x86_64-linux";
      VARS = import nix-secrets.vars.varsFile;
      treefmtEval = inputs.treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix;
      mkHost =
        hostname: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./system-loader.nix
            ./hosts/${hostname}/${hostname}.nix
            inputs.home-manager.nixosModules.home-manager
            inputs.sops-nix.nixosModules.sops
            inputs.lanzaboote.nixosModules.lanzaboote
            inputs.microvm.nixosModules.host
          ]
          ++ extraModules;
          specialArgs = {
            inherit
              inputs
              system
              VARS
              self
              ;
          };
        };
    in
    {
      nixosConfigurations = {
        snowfall = mkHost "snowfall" [ ];
        blizzard = mkHost "blizzard" [ ];
        avalanche = mkHost "avalanche" [ ];
        kaizer = mkHost "kaizer" [ ];

        # MicroVM definitions (for use with microvm.nix on a host)
        # Note: MicroVMs don't use system-loader.nix to avoid importing host-only modules
        adguard-vm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            inputs.microvm.nixosModules.microvm
            ./vms/adguard.nix
            inputs.sops-nix.nixosModules.sops
          ];
          specialArgs = { inherit inputs system VARS; };
        };

        actual-vm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            inputs.microvm.nixosModules.microvm
            ./vms/actual.nix
          ];
          specialArgs = { inherit inputs system VARS; };
        };
      };

      formatter.${system} = treefmtEval.config.build.wrapper;
      checks.${system}.formatting = treefmtEval.config.build.check inputs.self;
    };
}
