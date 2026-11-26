# Public-only evaluation; no private data, builds, or activation:
# nix eval --offline --impure --json --expr '
#   let
#     lock = builtins.fromJSON (builtins.readFile ./flake.lock);
#     source = builtins.fetchTree lock.nodes.${lock.nodes.${lock.root}.inputs.nixpkgs}.locked;
#   in (import ./tests/role-defaults.nix {
#     pkgs = import source { system = "x86_64-linux"; };
#   }).cases'
{ pkgs }:
let
  inherit (pkgs) lib;
  path = lib.splitString ".";
  routineBools = [
    "sys.boot.plymouth.enable"
    "sys.programs.java.enable"
    "sys.programs.gaming.enable"
    "sys.programs.gaming.steam.enable"
    "sys.services.pipewire.enable"
    "sys.services.printing.enable"
    "sys.services.flatpak.enable"
    "sys.virtualisation.enable"
  ];
  commonPolicy = [
    "sys.home.enable"
    "sys.boot.lanzaboote.enable"
    "sys.networking.base.enable"
    "sys.programs.ssh.enable"
    "sys.services.openssh.enable"
    "sys.services.openssh.openFirewall"
    "sys.services.timesyncd.enable"
    "sys.services.resolved.enable"
    "sys.services.maintenance.enable"
    "sys.services.tailscale.enable"
    "networking.firewall.enable"
  ];
  desktopPolicy = {
    "sys.networking.networkmanager.enable" = false;
    "sys.programs.gnupg.enable" = true;
    "sys.services.autoUpgrade.enable" = true;
    "hardware.keyboard.qmk.enable" = false;
    "hardware.keyboard.qmk.keychronSupport" = false;
  };
  serverPolicy = {
    "sys.networking.networkd.enable" = false;
    "sys.services.autoUpgrade.enable" = false;
    "sys.services.nfs.server.openFirewall" = true;
    "sys.services.autoUpgrade.dates" = "weekly";
    "sys.services.autoUpgrade.sshKeyPath" = "/tmp/role-policy-fixture";
  };
  stringPaths = [
    "sys.boot.plymouth.theme"
    "sys.services.autoUpgrade.dates"
    "sys.services.autoUpgrade.sshKeyPath"
  ];
  boolPaths = lib.unique (
    routineBools
    ++ commonPolicy
    ++ builtins.attrNames desktopPolicy
    ++ lib.filter (name: builtins.isBool serverPolicy.${name}) (builtins.attrNames serverPolicy)
  );
  schema =
    plymouthDefault:
    lib.forEach boolPaths (name: {
      options = lib.setAttrByPath (path name) (
        lib.mkOption {
          type = lib.types.bool;
          default = if name == "sys.boot.plymouth.enable" then plymouthDefault else false;
        }
      );
    })
    ++ lib.forEach stringPaths (name: {
      options = lib.setAttrByPath (path name) (
        lib.mkOption {
          type = lib.types.str;
          default = "";
        }
      );
    })
    ++ [
      {
        options = {
          environment.systemPackages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
          };
          sys.boot.plymouth.themePackages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
          };
          sys.overlays = {
            custom = lib.mkOption {
              type = lib.types.listOf lib.types.raw;
              default = [ ];
            };
            fromInputs = lib.mkOption {
              type = lib.types.attrsOf (lib.types.listOf lib.types.str);
              default = { };
            };
          };
        };
      }
    ];
  makeWithPlymouthDefault =
    plymouthDefault: role: settings:
    (lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        ../modules/core/roles.nix
        ../modules/role-desktop.nix
        ../modules/role-server.nix
        {
          _module.check = false;
          sys.role = {
            desktop.enable = role == "desktop";
            server.enable = role == "server";
          };
        }
        settings
      ]
      ++ schema plymouthDefault;
    }).config;
  make = makeWithPlymouthDefault false;
  read = name: cfg: lib.getAttrFromPath (path name) cfg;
  trySetting =
    role: name: value:
    builtins.tryEval (read name (make role (lib.setAttrByPath (path name) value)));
  accepts =
    role: name: value:
    let
      result = trySetting role name value;
    in
    result.success && result.value == value;
  rejects =
    role: name: value:
    !(trySetting role name value).success;
  desktop = make "desktop" { };
  extra = make "desktop" {
    environment.systemPackages = [ pkgs.hello ];
    sys = {
      boot.plymouth.themePackages = [ pkgs.hello ];
      overlays = {
        custom = [ (_final: _prev: { }) ];
        fromInputs.nixpkgs-unstable = [ "role-defaults-fixture" ];
      };
    };
  };
  inactive = make null { };
  has = name: packages: lib.any (p: lib.getName p == name) packages;
  cases = {
    defaults = lib.genAttrs routineBools (name: read name desktop) // {
      desktopTheme = read "sys.boot.plymouth.theme" desktop == "loader";
      serverPlymouthDisabled =
        !(read "sys.boot.plymouth.enable" (makeWithPlymouthDefault true "server" { }));
    };
    routine = lib.genAttrs routineBools (name: accepts "desktop" name false) // {
      serverPlymouthCanBeEnabled = accepts "server" "sys.boot.plymouth.enable" true;
      desktopThemeCanBeChanged = accepts "desktop" "sys.boot.plymouth.theme" "spinner";
    };
    policy = lib.listToAttrs (
      lib.concatMap
        (role: map (name: lib.nameValuePair "${role}.${name}" (rejects role name false)) commonPolicy)
        [
          "desktop"
          "server"
        ]
      ++ lib.mapAttrsToList (
        name: value: lib.nameValuePair "desktop.${name}" (rejects "desktop" name value)
      ) desktopPolicy
      ++ lib.mapAttrsToList (
        name: value: lib.nameValuePair "server.${name}" (rejects "server" name value)
      ) serverPolicy
    );
    collections = {
      systemPackagesAdd =
        has "asdf-vm" extra.environment.systemPackages && has "hello" extra.environment.systemPackages;
      themePackagesAdd =
        builtins.length extra.sys.boot.plymouth.themePackages
        == builtins.length desktop.sys.boot.plymouth.themePackages + 1
        && has "hello" extra.sys.boot.plymouth.themePackages;
      overlayFunctionsAdd =
        builtins.length extra.sys.overlays.custom == builtins.length desktop.sys.overlays.custom + 1;
      overlaySelectionsAdd =
        lib.all (
          name: lib.elem name extra.sys.overlays.fromInputs.nixpkgs-unstable
        ) desktop.sys.overlays.fromInputs.nixpkgs-unstable
        && lib.elem "role-defaults-fixture" extra.sys.overlays.fromInputs.nixpkgs-unstable;
      inactiveRolesAddNothing =
        inactive.environment.systemPackages == [ ]
        && inactive.sys.overlays.custom == [ ]
        && lib.all (name: !(read name inactive)) routineBools;
    };
  };
  failures = lib.concatLists (
    lib.mapAttrsToList (
      group: tests:
      map (name: "${group}.${name}") (builtins.attrNames (lib.filterAttrs (_: passed: !passed) tests))
    ) cases
  );
in
assert lib.assertMsg (
  failures == [ ]
) "Role-default contracts failed: ${lib.concatStringsSep ", " failures}";
pkgs.runCommand "role-default-tests" { passthru = { inherit cases; }; } ''
  touch "$out"
''
