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
#      inputs.nixpkgs.follows = "nixpkgs";
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
    , microvm
    #, crowdsec
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

                users.${myVars.mainUsers.server.user} = import ./users/server/home/home.nix;
              };
            }

#            crowdsec.nixosModules.crowdsec
#
#            ({ pkgs, lib, ... }: {
#              services.crowdsec = {
#                enable = true;
#
#                enrollKeyFile = "/opt/sec/crowdsec-file";
#
#                settings = {
#                  api.server = {
#                    listen_url = "127.0.0.1:9998";
#                  };
#                };
#              };
#            })
#
#            crowdsec.nixosModules.crowdsec-firewall-bouncer
#
#            ({ pkgs, lib, ... }: {
#              nixpkgs.overlays = [ crowdsec.overlays.default ];
#
#              services.crowdsec-firewall-bouncer = {
#                enable = true;
#
#                settings = {
#                  api_key = "a2aCfCdapZ3NdhlXfXhWB5KAwTs52q5r4EadFfPt";
#                  api_url = "http://localhost:9998";
#                };
#              };
#            })
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

                users = {
                  ${myVars.mainUsers.laptop.user} = import ./users/main/home/home.nix;
                  ${myVars.extraUsers.wife.user} = import ./users/extra/wife/home/home.nix;
                  ${myVars.extraUsers.brother-one.user} = import ./users/extra/brother-one/home/home.nix;
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
