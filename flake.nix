{
  description = "Full-deployment NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable-latest.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

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
      # gather hosts metadata in one place
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

      # read all overlays from ./overlays/*.nix
      overlayFiles = builtins.attrNames (builtins.readDir ./overlays);
      allOverlays = map (f: import (./overlays + "/" + f)) overlayFiles;
    in
    {
      # Colmena config
      colmena = {
        meta = {
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = allOverlays;
          };
          specialArgs = { inherit inputs VARS; };
        };
        inherit (hosts) snowfall blizzard avalanche;
      };

      # NixOS configurations
      nixosConfigurations = lib.mapAttrs
        (hostName: hostAttrs:
          nixpkgs.lib.nixosSystem {
            system = hostAttrs.system;
            modules = [
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "hm-backup";
                  sharedModules = [
                    inputs.sops-nix.homeManagerModules.sops
                    inputs.hyprland.homeManagerModules.default
                  ];

                  extraSpecialArgs = {
                    inherit inputs VARS;
                    pkgs-stable-latest = import inputs.nixpkgs-stable-latest {
                      system = hostAttrs.system;
                    };
                    pkgs-stable =
                      import inputs.nixpkgs-stable { system = hostAttrs.system; };
                    pkgs-unstable = import inputs.nixpkgs-unstable {
                      system = hostAttrs.system;
                    };
                  };

                  users = lib.genAttrs hostAttrs.users (user:
                    import ./hosts/${hostName}/home/users/${
                    if user == VARS.users.admin.user then
                      "admin"
                    else
                      "extra/${user}"
                  }/home.nix);
                };
              }
              hostAttrs.config
            ];

            specialArgs = {
              inherit inputs VARS;
              pkgs-stable-latest = import inputs.nixpkgs-stable-latest {
                system = hostAttrs.system;
              };
              pkgs-stable =
                import inputs.nixpkgs-stable { system = hostAttrs.system; };
              pkgs-unstable = import inputs.nixpkgs-unstable {
                system = hostAttrs.system;
              };
            };
          })
        hosts;
    };
}
