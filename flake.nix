# Refactored flake with simplified structure
{
  description = "Full-deployment NixOS flake - Refactored";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable-latest.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
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
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    crowdsec = {
      url = "git+https://codeberg.org/kampka/nix-flake-crowdsec.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      VARS = import inputs.nix-secrets.vars.varsFile;

      # Import custom library functions
      mylib = import ./lib/default.nix { inherit lib VARS; };

      # Host metadata - simplified
      hosts = {
        snowfall = {
          system = "x86_64-linux";
          config = ./hosts/snowfall/configuration.nix;
          users = [ VARS.users.admin.user ];
        };

        blizzard = {
          system = "x86_64-linux";
          config = ./hosts/blizzard/configuration.nix;
          users = [ VARS.users.admin.user ];
        };

        avalanche = {
          system = "x86_64-linux";
          config = ./hosts/avalanche/configuration.nix;
          users = [ VARS.users.admin.user ];
        };
      };

      # Overlays
      overlayFiles = builtins.attrNames (builtins.readDir ./overlays);
      allOverlays = map (f: import ./overlays/${f}) overlayFiles;

      # Helper to import multiple channels once per system
      mkChannels = system: {
        pkgs-stable-latest = import inputs.nixpkgs-stable-latest {
          inherit system;
          overlays = allOverlays;
        };
        pkgs-stable = import inputs.nixpkgs-stable {
          inherit system;
          overlays = allOverlays;
        };
        pkgs-unstable = import inputs.nixpkgs-unstable {
          inherit system;
          overlays = allOverlays;
        };
      };

      # Common system builder
      mkSystem = hostName: hostAttrs:
        let channels = mkChannels hostAttrs.system;
        in nixpkgs.lib.nixosSystem {
          system = hostAttrs.system;
          modules = [
            # Ensure overlays are applied to each system
            { nixpkgs.overlays = allOverlays; }

            inputs.home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                sharedModules = [
                  inputs.sops-nix.homeManagerModules.sops
                  inputs.hyprland.homeManagerModules.default
                  inputs.nix-colors.homeManagerModules.default
                ];

                extraSpecialArgs = { inherit inputs VARS mylib; } // channels;

                users = lib.genAttrs hostAttrs.users (user:
                  import ./hosts/${hostName}/home/users/${
                    if user == VARS.users.admin.user then
                      "admin"
                    else
                      "extra/${user}"
                  }/home.nix);
              };
            }
            inputs.sops-nix.nixosModules.sops
            hostAttrs.config
          ];
          specialArgs = { inherit inputs VARS mylib; } // channels;
        };

      defaultSystem = "x86_64-linux";
      pkgsFor = system: import nixpkgs { inherit system; overlays = allOverlays; };
    in
    {
      # Colmena config
      colmena = {
        meta = {
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = allOverlays;
          };
          specialArgs = { inherit inputs VARS mylib; };
        };
        inherit (hosts) snowfall blizzard avalanche;
      };

      # NixOS configurations
      nixosConfigurations = lib.mapAttrs mkSystem hosts;

      # Formatter
      formatter.x86_64-linux = (import nixpkgs {
        system = "x86_64-linux";
        overlays = allOverlays;
      }).alejandra;

      # Dev shell with common tooling
      devShells.x86_64-linux.default =
        let
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = allOverlays;
          };
        in
        pkgs.mkShell {
          name = "nix-config-dev";
          packages = with pkgs; [
            alejandra
            statix
            deadnix
            sops
            colmena
            nix-output-monitor
            git
          ];
        };

      # Checks
      checks.${defaultSystem} = let pkgs = pkgsFor defaultSystem; in {
        fmt = pkgs.runCommand "fmt-check" { } ''
          ${pkgs.alejandra}/bin/alejandra --check ${./.} || (echo "Formatting issues"; exit 1)
          touch $out
        '';
        deadnix = pkgs.runCommand "deadnix" { } ''
          ${pkgs.deadnix}/bin/deadnix --fail --no-lambda-pattern-names ${./.}
          touch $out
        '';
        statix = pkgs.runCommand "statix" { } ''
          ${pkgs.statix}/bin/statix check ${./.}
          touch $out
        '';
        flakeEval = pkgs.runCommand "flake-eval" { } ''
          nix flake check --no-build --print-build-logs ${./.}
          touch $out
        '';
      };
    };
}
