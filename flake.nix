{
  description = "NixOS configuration with auto-imported modules";

  inputs = {
    # Primary channel - most packages come from here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Stable fallbacks for packages broken on unstable
    nixpkgs-stable-latest.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    # Bleeding-edge channel for packages that need the latest commits
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };

    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      flake = false;
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pre-commit.inputs.flake-compat.follows = "flake-compat";
        pre-commit.inputs.gitignore.follows = "gitignore";
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

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs = {
        pre-commit-hooks.inputs.flake-compat.follows = "flake-compat";
        pre-commit-hooks.inputs.gitignore.follows = "gitignore";
      };
    };

    nix-colors.url = "github:misterio77/nix-colors";

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

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
      consts = import ./lib/constants.nix;
      treefmtEval = inputs.treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix;
      microvmConfigurations = import ./vms/flake-microvms.nix {
        inherit inputs system VARS;
      };
      mkHost =
        hostname: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./system-loader.nix
            ./host-loader.nix
            inputs.disko.nixosModules.disko
            inputs.home-manager.nixosModules.home-manager
            inputs.sops-nix.nixosModules.sops
            inputs.lanzaboote.nixosModules.lanzaboote
            inputs.microvm.nixosModules.host
            inputs.quadlet-nix.nixosModules.quadlet
          ]
          ++ extraModules;
          specialArgs = {
            inherit
              inputs
              system
              VARS
              consts
              self
              hostname
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
      }
      // microvmConfigurations;

      formatter.${system} = treefmtEval.config.build.wrapper;
      checks.${system}.formatting = treefmtEval.config.build.check inputs.self;

      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = with nixpkgs.legacyPackages.${system}; [
          nil
          nixfmt
          deadnix
          statix
          sops
          ssh-to-age
        ];
      };
    };
}
