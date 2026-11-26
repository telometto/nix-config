# Exercise host-owned profiles with the actual builder, option declarations,
# NixOS and HM bridge. Only the unrelated HM tree and external schemas are stubbed.
{ pkgs, hmStable }:
let
  inherit (pkgs) lib;
  consts = import ../lib/constants.nix;
  hosts = {
    snowfall = {
      module = ../hosts/snowfall/containers.nix;
      ownerRole = "zeno";
      service = "ollama-container";
    };
    blizzard = {
      module = ../hosts/blizzard/virtualisation/containers.nix;
      ownerRole = "zeno";
      service = "lingarr";
    };
    kaizer = {
      module = ../hosts/kaizer/containers.nix;
      ownerRole = "luke";
      service = "immich-machine-learning-container";
    };
  };
  cases =
    host:
    let
      profilesFor =
        {
          homeEnabled ? true,
          userEnabled ? null,
        }:
        let
          evaluate =
            modules:
            import "${pkgs.path}/nixos/lib/eval-config.nix" {
              inherit pkgs;
              system = pkgs.stdenv.hostPlatform.system;
              specialArgs = {
                inherit consts;
                VARS.users = {
                  ${host.ownerRole} = {
                    user = "alice";
                    isNormalUser = true;
                  };
                  other = {
                    user = "bob";
                    isNormalUser = true;
                  };
                };
              };
              modules = [
                ../modules/core/home-options.nix
                ../modules/core/user-options.nix
                ../modules/core/roles.nix
                ../modules/desktop/base.nix
                {
                  networking.hostName = "container-optout-fixture";
                  system.stateVersion = "26.05";
                  users.users = {
                    alice.isNormalUser = true;
                    bob.isNormalUser = true;
                  };
                  sys = {
                    users = {
                      alice.enable = true;
                      bob.enable = true;
                    };
                    home = {
                      enable = homeEnabled;
                      template.home.stateVersion = "26.05";
                      users = lib.optionalAttrs (userEnabled != null) {
                        alice.enable = userEnabled;
                      };
                    };
                  };
                }
              ]
              ++ modules;
            };
          # Resolve the real builder's conditions before replacing the HM tree.
          # Disabling the loader as an HM module would still collect its imports.
          profiles =
            (evaluate [
              ../modules/core/home-users.nix
              {
                options.home-manager.users = lib.mkOption {
                  type = lib.types.attrsOf lib.types.raw;
                  default = { };
                };
              }
            ]).config.home-manager.users;
        in
        (evaluate [
          "${hmStable}/nixos"
          host.module
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit consts; };
              users = lib.mapAttrs (
                _: profile:
                profile
                // {
                  imports = lib.remove ../hm-loader.nix profile.imports;
                }
              ) profiles;
              sharedModules = [
                {
                  options = {
                    virtualisation.quadlet = lib.mkOption {
                      type = lib.types.attrs;
                      default = { };
                    };
                    sops = lib.mkOption {
                      type = lib.types.attrs;
                      default = { };
                    };
                  };
                }
              ];
            };
          }
        ]).config.home-manager.users;
      enabled = profilesFor { };
      explicitlyEnabled = profilesFor { userEnabled = true; };
      disabled = profilesFor { userEnabled = false; };
      globallyDisabled = profilesFor { homeEnabled = false; };
    in
    {
      enabledProfilesRetained =
        builtins.attrNames enabled == [
          "alice"
          "bob"
        ];
      enabledContainerRetained = enabled.alice.services.${host.service}.enable;
      enabledProfileComplete = enabled.alice.home.stateVersion == "26.05";
      explicitEnableRetainsContainer = explicitlyEnabled.alice.services.${host.service}.enable;
      disabledOwnerProfileOmitted = builtins.attrNames disabled == [ "bob" ];
      otherProfileSurvivesOptOut = disabled.bob.home.stateVersion == "26.05";
      globalOptOutOmitsAllProfiles = builtins.attrNames globallyDisabled == [ ];
    };
in
lib.listToAttrs (
  lib.concatLists (
    lib.mapAttrsToList (
      hostname: host:
      lib.mapAttrsToList (name: value: lib.nameValuePair "${hostname}-${name}" value) (cases host)
    ) hosts
  )
)
