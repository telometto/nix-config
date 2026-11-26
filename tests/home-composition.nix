# Exercise the real user builder with synthetic metadata. Only the unrelated
# auto-loaded HM tree is replaced by a small option schema; selected overrides
# and template/extra-module imports still go through native module evaluation.
{ pkgs, hmStable }:
let
  inherit (pkgs) lib;
  withoutBase = profile: profile // { imports = lib.remove ../hm-loader.nix profile.imports; };
  make =
    {
      hostName ? "composition-fixture",
      role ? null,
      disabled ? false,
      userHome ? null,
      systemHome ? "/srv/alice",
      username ? "alice",
      templateModule ? { },
      userModule ? { },
    }:
    let
      cfg = {
        enable = true;
        extraModules = [ { home.packages = [ pkgs.git ]; } ];
        template = {
          imports = [ { home.packages = [ pkgs.jq ]; } ];
          home.packages = [ pkgs.hello ];
          hm.desktop.kde.enable = false;
        }
        // templateModule;
        users.${username} = {
          enable = !disabled;
          extraModules = [ { home.packages = [ pkgs.tree ]; } ];
          extraConfig = {
            imports = [ { home.packages = [ pkgs.ripgrep ]; } ];
            home.packages = [ pkgs.cowsay ];
          }
          // userModule;
        };
      };
      result = import ../modules/core/home-users.nix {
        inherit lib pkgs;
        VARS.users = {
          owner = {
            user = username;
            isNormalUser = true;
          }
          // lib.optionalAttrs (userHome != null) { home = userHome; };
          other = {
            user = "bob";
            isNormalUser = true;
          };
          service = {
            user = "service-fixture";
            isNormalUser = false;
          };
          inactive = {
            user = "inactive-fixture";
            isNormalUser = true;
          };
        };
        config = {
          networking = { inherit hostName; };
          users.users.${username} = lib.optionalAttrs (systemHome != null) { home = systemHome; };
          sys = {
            home = cfg;
            users = {
              ${username}.enable = true;
              bob.enable = true;
              service-fixture.enable = true;
              inactive-fixture.enable = false;
            };
            role = {
              desktop.enable = role == "desktop";
              server.enable = role == "server";
            };
            desktop.flavor = "kde";
          };
        };
      };
      # Resolve conditional user definitions before evaluating their HM modules.
      profiles =
        (lib.evalModules {
          modules = [
            {
              options.profiles = lib.mkOption {
                type = lib.types.attrsOf lib.types.raw;
                default = { };
              };
              config.profiles = result.config.content.home-manager.users;
            }
          ];
        }).config.profiles;
      evaluate =
        profile:
        (lib.evalModules {
          specialArgs = { inherit pkgs; };
          modules = [
            {
              config._module.check = false;
              options = {
                home = {
                  username = lib.mkOption { type = lib.types.str; };
                  homeDirectory = lib.mkOption { type = lib.types.str; };
                  packages = lib.mkOption {
                    type = lib.types.listOf lib.types.package;
                    default = [ ];
                  };
                };
                hm.desktop.kde.enable = lib.mkEnableOption "fixture KDE integration";
              };
            }
            (withoutBase profile)
          ];
        }).config;
    in
    {
      inherit profiles;
      users = lib.mapAttrs (_: evaluate) profiles;
    };
  main = make { };
  alice = main.users.alice;
  names = user: map lib.getName user.home.packages;
  selection = args: (make args).profiles.zeno.imports;
  snowfall = selection {
    hostName = "snowfall";
    username = "zeno";
    role = "desktop";
  };
  blizzard = selection {
    hostName = "blizzard";
    username = "zeno";
    role = "server";
  };
  # Include the actual NixOS/HM bridge: it supplies account identity/home at
  # ordinary priority, above the builder's fallback defaults.
  integrated =
    {
      disabled ? false,
      templateModule ? { },
      userModule ? { },
    }:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      inherit pkgs;
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        "${hmStable}/nixos"
        {
          system.stateVersion = "26.05";
          users.users = {
            alice = {
              isNormalUser = true;
              home = "/srv/account-home";
            };
            bob.isNormalUser = true;
          };
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            sharedModules = [
              {
                options.hm.desktop.kde.enable = lib.mkEnableOption "fixture KDE integration";
                config.home.stateVersion = "26.05";
              }
            ];
            users =
              lib.mapAttrs (_: withoutBase)
                (make {
                  inherit disabled templateModule userModule;
                  userHome = "/srv/metadata-home";
                }).profiles;
          };
        }
      ];
    }).config.home-manager.users;
  templateImport = {
    imports = [ ../home/packages.nix ];
  };
  importedPackages = integrated { templateModule = templateImport; };
  templateDisabledPackages = integrated {
    templateModule = templateImport // {
      disabledModules = [ ../home/packages.nix ];
    };
  };
  userDisabledPackages = integrated {
    templateModule = templateImport;
    userModule.disabledModules = [ ../home/packages.nix ];
  };
in
{
  templatePackagesPreserved = lib.elem "hello" (names alice);
  userPackagesAppended = lib.elem "cowsay" (names alice);
  hostExtraModulesApplied = lib.elem "git" (names alice);
  templateImportsApplied = lib.elem "jq" (names alice);
  userExtraModulesApplied = lib.elem "tree" (names alice);
  userConfigImportsApplied = lib.elem "ripgrep" (names alice);
  userAdditionsStayWithUser = !(lib.elem "cowsay" (names main.users.bob));
  disabledProfileOmitted = !((make { disabled = true; }).profiles ? alice);
  otherUserSurvivesOptOut = (make { disabled = true; }).profiles ? bob;
  nonNormalUserExcluded = !(main.profiles ? service-fixture);
  inactiveUserExcluded = !(main.profiles ? inactive-fixture);
  systemHomeSuppliesBuilderDefault = alice.home.homeDirectory == "/srv/alice";
  metadataSuppliesBuilderDefault =
    (make { userHome = "/srv/metadata-home"; }).users.alice.home.homeDirectory == "/srv/metadata-home";
  missingHomeFallsBack =
    (make { systemHome = null; }).users.alice.home.homeDirectory == "/home/alice";
  explicitDesktopOptOutRespected = !alice.hm.desktop.kde.enable;
  accountHomeOverridesMetadataDefault =
    (integrated { }).alice.home.homeDirectory == "/srv/account-home";
  integratedPackageListsCombine = lib.all (name: lib.elem name (names (integrated { }).alice)) [
    "hello"
    "cowsay"
    "git"
    "jq"
    "tree"
    "ripgrep"
  ];
  integratedUserOptOutRespected = !((integrated { disabled = true; }) ? alice);
  templateCanDisableImportedModule =
    lib.elem "dupe-krill" (names importedPackages.alice)
    && !(lib.elem "dupe-krill" (names templateDisabledPackages.alice));
  userConfigCanDisableImportedModule =
    lib.elem "dupe-krill" (names importedPackages.alice)
    && !(lib.elem "dupe-krill" (names userDisabledPackages.alice));
  userDisabledModuleDoesNotLeak = lib.elem "dupe-krill" (names userDisabledPackages.bob);
  desktopRoleSelected = lib.elem ../home/overrides/role/desktop.nix snowfall;
  serverRoleNotSelectedForDesktop = !(lib.elem ../home/overrides/role/server.nix snowfall);
  hostOverrideSelected = lib.elem ../home/overrides/host/snowfall.nix snowfall;
  userOverrideSelected = lib.elem ../home/overrides/user/zeno.nix snowfall;
  userHostOverrideSelected = lib.elem ../home/overrides/user/zeno-snowfall.nix snowfall;
  serverRoleSelected = lib.elem ../home/overrides/role/server.nix blizzard;
  desktopRoleNotSelectedForServer = !(lib.elem ../home/overrides/role/desktop.nix blizzard);
  hostOverridesDoNotLeak = !(lib.elem ../home/overrides/host/snowfall.nix blizzard);
  userHostOverridesDoNotLeak = !(lib.elem ../home/overrides/user/zeno-snowfall.nix blizzard);
}
