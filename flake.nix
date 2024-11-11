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
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # MicroVM repo
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

    # Nixarr repo (test)
    #nixarr.url = "github:rasmus-kirk/nixarr";
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , home-manager
    , nixos-hardware
    , lanzaboote
    , agenix
      #, sops-nix
    , microvm
      #, crowdsec
      #, #vpn-confinement
      #, nixarr
    , ...
    }:
    let
      myVars = import ./common/vars/vars.nix;
    in
    {
      nixosConfigurations = {
        homeserver = nixpkgs.lib.nixosSystem {
          system = myVars.general.system;

          modules = [
            ./hosts/server/configuration.nix

            # Start Home Manager configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";

                extraSpecialArgs = { inherit myVars; };

                users.${myVars.mainUsers.server.user} = import ./common/users/server/home/home.nix;
              };
            }
          ];

          specialArgs = {
            inherit inputs myVars;
          };
        };

        snowfall = nixpkgs.lib.nixosSystem {
          system = myVars.general.system;

          modules = [
            ./hosts/desktop/configuration.nix

            # Start Home Manager configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";

                extraSpecialArgs = { inherit myVars; };

                users.${myVars.mainUsers.desktop.user} = import ./common/users/main/home/home.nix;
              };
            }
          ];

          specialArgs = {
            inherit inputs myVars;
          };
        };

        stinkpad = nixpkgs.lib.nixosSystem {
          system = myVars.general.system;

          modules = [
            ./hosts/laptop/configuration.nix

            # Start Home Manager configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";

                extraSpecialArgs = { inherit myVars; };

                users = {
                  ${myVars.mainUsers.laptop.user} = import ./common/users/main/home/home.nix;
                  ${myVars.extraUsers.wife.user} = import ./common/users/extra/wife/home/home.nix;
                  ${myVars.extraUsers.brother-one.user} = import ./common/users/extra/brother-one/home/home.nix;
                };
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
