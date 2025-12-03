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
        # rust-overlay.follows = "rust-overlay";
      };
    };

    # rust-overlay = {
    # url = "github:oxalica/rust-overlay";
    # inputs.nixpkgs.follows = "nixpkgs";
    # };

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
    inputs@{ nixpkgs, nix-secrets, ... }:
    let
      system = "x86_64-linux";
      # Import VARS from your secrets repository
      VARS = import nix-secrets.vars.varsFile;

      # Treefmt configuration
      treefmtEval = inputs.treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix;

      # Host configuration template
      mkHost =
        hostname: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./system-loader.nix
            ./hosts/${hostname}/${hostname}.nix
            # External modules
            inputs.home-manager.nixosModules.home-manager
            inputs.vscode-server.nixosModules.default
            inputs.sops-nix.nixosModules.sops
            inputs.lanzaboote.nixosModules.lanzaboote
            inputs.microvm.nixosModules.host
          ]
          ++ extraModules;
          specialArgs = { inherit inputs system VARS; };
        };
    in
    {
      nixosConfigurations = {
        snowfall = mkHost "snowfall" [ ];
        blizzard = mkHost "blizzard" [ ];
        avalanche = mkHost "avalanche" [ ];
        kaizer = mkHost "kaizer" [ ];
      };

      # Formatter (treefmt)
      formatter.${system} = treefmtEval.config.build.wrapper;

      # Expose treefmt as a check
      checks.${system}.formatting = treefmtEval.config.build.check inputs.self;
    };
}
