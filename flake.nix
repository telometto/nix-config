{
  description = "A simple NixOS flake";

  inputs = {
    # Nixpkgs repos
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
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
    vpn-confinement = { url = "github:Maroka-chan/VPN-Confinement"; };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # mySecrets = {
    #   url = "git+ssh://git@gitlab.com/telometto/nix-secrets.git?ref=main&shallow=1";
    #   flake = false;
    # };

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

    base16 = { url = "github:SenchoPens/base16.nix"; };

    tt-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };

    hyprland = { url = "github:hyprwm/Hyprland"; };

    # Nixarr repo (test)
    #nixarr.url = "github:rasmus-kirk/nixarr";
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , nixpkgs-stable
    , nixpkgs-unstable
    , home-manager
    , nixos-hardware
    , lanzaboote
    , agenix
    , sops-nix
    , microvm
      # , crowdsec
      # , vpn-confinement
    , hyprland
      # , nixarr
    , ...
    }:
    let
      myVars = import ./common/vars/vars.nix;

      hostConfigs = {
        snowfall = [ ./hosts/desktop/configuration.nix ];
        blizzard = [ ./hosts/server/configuration.nix ];
        stinkpad = [ ./hosts/laptop/configuration.nix ];
      };
    in
    {
      colmena = {
        meta = {
          # name = "homelab";
          # description = "My colmena homelab";
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = [ ];
          };

          specialArgs = { inherit inputs myVars; };
        };

        # snowfall = ./hosts/desktop;
        blizzard = ./hosts/server;
        # stinkpad = ./hosts/laptop;
      };

      nixosConfigurations = {
        snowfall = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            # Start Home Manager configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                sharedModules = [
                  inputs.sops-nix.homeManagerModules.sops
                  inputs.hyprland.homeManagerModules.default
                ];

                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";

                extraSpecialArgs = { inherit inputs myVars; };

                users.${myVars.users.admin.user} = import ./common/users/main/home/home.nix;
              };
            }
          ] ++ hostConfigs.snowfall;

          specialArgs = { inherit inputs myVars; };
        };

        blizzard = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            # Start Home Manager configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];

                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";

                extraSpecialArgs = { inherit myVars; };

                users.${myVars.users.serverAdmin.user} = import ./common/users/server/home/home.nix;
              };
            }
          ] ++ hostConfigs.blizzard;

          specialArgs = { inherit inputs myVars; };
        };

        stinkpad = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            # Start Home Manager configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";

                extraSpecialArgs = { inherit inputs myVars; };

                users = {
                  ${myVars.users.admin.user} = import ./common/users/main/home/home.nix;
                  ${myVars.users.wife.user} = import ./common/users/extra/wife/home/home.nix;
                  ${myVars.users.luke.user} = import ./common/users/extra/luke/home/home.nix;
                  ${myVars.users.frankie.user} = import ./common/users/extra/frankie/home/home.nix;
                };
              };
            }
          ] ++ hostConfigs.stinkpad;

          specialArgs = {
            inherit inputs myVars;
          };
        };
      };
    };
}
