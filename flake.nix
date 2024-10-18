{
  description = "A simple NixOS flake";

  inputs = {
    # Nixpkgs repos
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    # NixOS Hardware repo
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Home Manager repo
    home-manager = {
      #url = "github:nix-community/home-manager/release-24.05"; # Stable
      url = "github:nix-community/home-manager/master"; # Unstable
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure boot repo
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # VPN confinement repo
    vpn-confinement = {
      url = "github:Maroka-chan/VPN-Confinement";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # MicroVM repo
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixarr repo (test)
    #nixarr.url = "github:rasmus-kirk/nixarr";
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , home-manager
    , lanzaboote
    , agenix
    , microvm
    , #vpn-confinement, # works
      #nixarr,
      ...
    }:
    let
      myVars = import "${self}/vars/vars.nix";
    in
    {
      nixosConfigurations = {
        homeserver = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/server/configuration.nix

            # Start Home Manager configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;

                extraSpecialArgs = { inherit myVars; };

                users.${myVars.server.user} = import ./modules/server/home/home.nix;
              };
            }
          ];

          specialArgs = {
            inherit inputs myVars;
          };
        };

        stinkpad = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/laptop/configuration.nix

            # Start Home Manager configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;

                extraSpecialArgs = { inherit myVars; };

                users.${myVars.laptop.user} = import ./modules/laptop/home/home.nix;
              };
            }
          ];

          specialArgs = {
            inherit inputs myVars;
          };
        };
      };
    };
}
