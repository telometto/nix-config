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
      allOverlays = map (f: import (./overlays + "/" + f)) overlayFiles;

      # Common system builder
      mkSystem = hostName: hostAttrs:
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
                  inputs.nix-colors.homeManagerModules.default
                ];

                extraSpecialArgs = {
                  inherit inputs VARS mylib;
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
            inputs.sops-nix.nixosModules.sops
            hostAttrs.config
          ];
          specialArgs = {
            inherit inputs VARS mylib;
            pkgs-stable-latest = import inputs.nixpkgs-stable-latest {
              system = hostAttrs.system;
            };
            pkgs-stable =
              import inputs.nixpkgs-stable { system = hostAttrs.system; };
            pkgs-unstable =
              import inputs.nixpkgs-unstable { system = hostAttrs.system; };
          };
        };

    in {
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

      # NixOS VM tests: verify SOPS wiring and secret paths per host
      nixosTests = let
        mkSopsVmTest = hostName: hostAttrs: let
          system = hostAttrs.system;
          pkgsFor = import inputs.nixpkgs { inherit system; };
          makeTest = import (inputs.nixpkgs + "/nixos/tests/make-test-python.nix") { inherit system; pkgs = pkgsFor; };
          ts = "/run/secrets/general/tsKeyFilePath";
          pl = "/run/secrets/general/paperlessKeyFilePath";
          sx = "/run/secrets/general/searxSecretKey";
        in makeTest {
          name = "sops-${hostName}";
          nodes.machine = { config, lib, ... }: {
            _module.args = {
              inherit inputs VARS mylib;
              pkgs-stable-latest = import inputs.nixpkgs-stable-latest { inherit system; };
              pkgs-stable = import inputs.nixpkgs-stable { inherit system; };
              pkgs-unstable = import inputs.nixpkgs-unstable { inherit system; };
            };
            imports = [
              ./hosts/${hostName}/configuration.nix
              ({ config, lib, ... }: {
                services.tailscale.enable = false;
                systemd.tmpfiles.rules = [
                  "d ${lib.dirOf ts} 0755 root root -"
                  "f ${ts} 0400 root root -"
                  "d ${lib.dirOf pl} 0755 root root -"
                  "f ${pl} 0400 root root -"
                  "d ${lib.dirOf sx} 0755 root root -"
                  "f ${sx} 0400 root root -"
                ];
              })
            ];
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.succeed("grep -q 'access-tokens =' /etc/nix/nix.conf")
            machine.succeed("grep -q 'extra-access-tokens' /etc/nix/nix.conf")
            machine.succeed("test -f ${ts}")
            machine.succeed("test -f ${pl}")
            machine.succeed("test -f ${sx}")
          '';
        };
      in
        (lib.mapAttrs mkSopsVmTest hosts)
        // (lib.mapAttrs' (name: hostAttrs: { name = "sops-${name}"; value = mkSopsVmTest name hostAttrs; }) hosts);

      # Lightweight evaluation checks for SOPS wiring per host
      checks = lib.mapAttrs (hostName: hostAttrs: let
        sys = builtins.getAttr hostName self.nixosConfigurations;
        cfg = sys.config;
        pkgsFor = import nixpkgs { system = hostAttrs.system; };
        extra = cfg.nix.extraOptions or "";
        hasInclude = (builtins.match ".*!include.*access-tokens.*" extra) != null;
        hasTs = builtins.hasAttr "general/tsKeyFilePath" cfg.sops.secrets;
        hasTok1 = builtins.hasAttr "tokens/gh-ns-test" cfg.sops.secrets;
        hasTok2 = builtins.hasAttr "tokens/github-ns" cfg.sops.secrets;
        hasTok3 = builtins.hasAttr "tokens/gitlab-fa" cfg.sops.secrets;
        hasTok4 = builtins.hasAttr "tokens/gitlab-ns" cfg.sops.secrets;
        hasPaperless = builtins.hasAttr "general/paperlessKeyFilePath" cfg.sops.secrets;
        hasSearx = builtins.hasAttr "general/searxSecretKey" cfg.sops.secrets;
        tailscaleOk = cfg.services.tailscale.authKeyFile == cfg.sops.secrets."general/tsKeyFilePath".path;
        hasAgeHostKey = builtins.elem "/etc/ssh/ssh_host_ed25519_key" cfg.sops.age.sshKeyPaths;
      in
        assert hasInclude && hasTs && hasTok1 && hasTok2 && hasTok3 && hasTok4 && hasAgeHostKey && hasPaperless && hasSearx && tailscaleOk;
        pkgsFor.runCommand "sops-check-${hostName}" { } ''
          echo "SOPS checks passed for ${hostName}" > $out
        ''
      ) hosts;
    };
}
