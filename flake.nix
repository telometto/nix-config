/**
 * Description:
 *   This flake serves as a complete NixOS deployment configuration managed via Colmena.
 *   It orchestrates multiple host configurations, ensuring consistent and reproducible environments.
 *   
 *   Inputs are organized into the following categories for better maintainability and clarity:
 *     - **Nixpkgs:** Core package repositories, including stable and unstable branches.
 *     - **NixOS Hardware:** Hardware-specific configurations and modules.
 *     - **Home Manager:** User environment management tools.
 *     - **Security:** Tools and modules related to secure boot and secret management.
 *     - **VPN:** Configurations for VPN confinement.
 *     - **Virtualization:** Virtual machine management tools.
 *     - **File Systems:** Disk management utilities.
 *     - **Theming:** Customization of system aesthetics.
 *     - **Desktop Environments:** Configuration for desktop environments like Hyprland.
 *     - **Management Tools:** Orchestration tools like Colmena for deploying configurations.
 *   
 * Usage:
 *   - **Deploy Configurations:**
 *       Use `nixos-rebuild` or `colmena` commands with this flake to deploy or update host configurations.
 *       Example: `colmena deploy -f .#snowfall`
 *   
 *   - **Manage Inputs:**
 *       Inputs are categorized for ease of updates and maintenance. Modify inputs within their respective categories as needed.
 *   
 *   - **Handle Secrets:**
 *       Ensure that secrets are managed securely via `nix-secrets`. Update the `vars.varsFile` as required.
 *   
 *   - **Extend Configurations:**
 *       Add new host configurations by updating the `hostConfigs` and corresponding user definitions.
 */

{
  description = "Full-deployment NixOS flake";

  inputs = {
    ### Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    ### NixOS Hardware repo
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    ### Home Manager repo
    home-manager = {
      url = "github:nix-community/home-manager/master"; # Unstable
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ### Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets
    agenix = {
      url = "github:ryantm/agenix";
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

    ### VPN confinement repo
    vpn-confinement = { url = "github:Maroka-chan/VPN-Confinement"; };

    ### Virtualization
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ### Security
    crowdsec = {
      url = "git+https://codeberg.org/kampka/nix-flake-crowdsec.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ### File systems
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ### Pimping
    base16 = { url = "github:SenchoPens/base16.nix"; };

    tt-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };

    ### Desktop environments
    hyprland = { url = "github:hyprwm/Hyprland"; };

    ### NixOps
    colmena = { url = "github:zhaofengli/colmena"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Nixarr repo (test)
    #nixarr.url = "github:rasmus-kirk/nixarr";
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      VARS = import inputs.nix-secrets.vars.varsFile;

      hostUsers = {
        snowfall = [ VARS.users.admin.user ];
        blizzard = [ VARS.users.admin.user ];
        avalanche = [ VARS.users.admin.user VARS.users.frankie.user VARS.users.luke.user ];
      };

      # Define a function to generate host configurations
      mkConfig = host: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # Start Home Manager configuration
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager = {
              sharedModules = [
                inputs.sops-nix.homeManagerModules.sops
                inputs.hyprland.homeManagerModules.default
              ];
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = { inherit inputs VARS; };
              users = nixpkgs.lib.genAttrs hostUsers.${host} (user:
                import ./hosts/${host}/home/users/${if user == VARS.users.admin.user then "admin" else "extra/${user}"}/home.nix
              );
            };
          }
        ] ++ hostConfigs.${host};
        specialArgs = { inherit inputs VARS; };
      };

      hostConfigs = {
        snowfall = [ ./hosts/snowfall/configuration.nix ];
        blizzard = [ ./hosts/blizzard/configuration.nix ];
        avalanche = [ ./hosts/avalanche/configuration.nix ];
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
      };

      nixosConfigurations = {
        snowfall = mkConfig "snowfall";
        blizzard = mkConfig "blizzard";
        avalanche = mkConfig "avalanche";
      };
    };
}
