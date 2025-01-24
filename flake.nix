/**
 * This `flake.nix` file provides a comprehensive NixOS deployment configuration managed via Colmena.
 * It defines multiple host configurations and organizes inputs into categories such as Nixpkgs, Home Manager, Security, and more.
 * 
 * **Usage:**
 * - **Deploy Configurations:**
 *   Use `nixos-rebuild` or `colmena` commands to deploy or update host configurations.
 *   Example: `colmena deploy -f .#hostname`
 * 
 * - **Manage Inputs:**
 *   Modify inputs within their respective categories for updates and maintenance.
 * 
 * - **Handle Secrets:**
 *   Securely manage secrets via `nix-secrets`. Update the `vars.varsFile` as required.
 * 
 * - **Extend Configurations:**
 *   Add new host configurations by updating `hostConfigs` and user definitions.
 */

{
  description = "Full-deployment NixOS flake";

  inputs = {
    ## Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable-latest.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    ## NixOS Hardware repo
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    ## Home Manager repo
    home-manager = {
      url = "github:nix-community/home-manager/master"; # Unstable
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ## Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ## Secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-secrets = {
      url = "git+ssh://git@github.com/telometto/nix-secrets.git";
      flake = true;
    };

    ## Virtualization
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ## Security
    crowdsec = {
      url = "git+https://codeberg.org/kampka/nix-flake-crowdsec.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ## File systems
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ## Pimping
    # base16 = { url = "github:SenchoPens/base16.nix"; };

    # tt-schemes = {
    #   url = "github:tinted-theming/schemes";
    #   flake = false;
    # };

    ## Desktop environments
    hyprland = { url = "github:hyprwm/Hyprland"; };

    ## NixOps
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , nixpkgs-stable-latest
    , nixpkgs-stable
    , nixpkgs-unstable
    , ...
    }:
    let
      VARS = import inputs.nix-secrets.vars.varsFile;

      ## Define host users
      hostUsers = {
        snowfall = [ VARS.users.admin.user VARS.users.luke.user ];
        blizzard = [ VARS.users.admin.user ];
        avalanche = [ VARS.users.admin.user VARS.users.luke.user ];
        frostbite = [ VARS.users.admin.user ]; # Placeholder
      };

      ## Define host architecture
      hostArch = {
        snowfall = "x86_64-linux";
        blizzard = "x86_64-linux";
        avalanche = "x86_64-linux";
        frostbite = "aarch64-linux"; # Placeholder
      };

      ## Define host configurations
      hostConfigs = {
        snowfall = [ ./hosts/snowfall/configuration.nix ];
        blizzard = [ ./hosts/blizzard/configuration.nix ];
        avalanche = [ ./hosts/avalanche/configuration.nix ];
        # frostbite = [ ./hosts/frostbite/configuration.nix ]; # Placeholder
      };

      # Define a function to generate host configurations
      mkConfig = host: nixpkgs.lib.nixosSystem rec {
        system = hostArch.${host};

        modules = [
          ## Start Home Manager configuration
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
                pkgs-stable-latest = import nixpkgs-stable-latest { inherit system; };
                pkgs-stable = import nixpkgs-stable { inherit system; };
                pkgs-unstable = import nixpkgs-unstable { inherit system; };

                inherit inputs VARS;
              };

              users = nixpkgs.lib.genAttrs hostUsers.${host} (user:
                import ./hosts/${host}/home/users/${
                    if user == VARS.users.admin.user
                    then "admin"
                    else "extra/${user}"
                  }/home.nix
              );
            };
          }
        ] ++ hostConfigs.${host};

        specialArgs = {
          pkgs-stable-latest = import nixpkgs-stable-latest { inherit system; };
          pkgs-stable = import nixpkgs-stable { inherit system; };
          pkgs-unstable = import nixpkgs-unstable { inherit system; };

          inherit inputs VARS;
        };
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

          specialArgs = { inherit inputs VARS; };
        };

        snowfall = ./hosts/snowfall;
        # blizzard = ./hosts/blizzard;
        # avalanche = ./hosts/avalanche;
        # frostbite = ./hosts/frostbite;
      };

      nixosConfigurations = {
        snowfall = mkConfig "snowfall";
        blizzard = mkConfig "blizzard";
        avalanche = mkConfig "avalanche";
        # frostbite = mkConfig "frostbite"; # Placeholder
      };
    };
}
