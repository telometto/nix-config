# Public-only invocation (no private input or activation):
# nix eval --offline --impure --json --expr '
#   let
#     lock = builtins.fromJSON (builtins.readFile ./flake.lock);
#     source = name:
#       builtins.fetchTree lock.nodes.${lock.nodes.${lock.root}.inputs.${name}}.locked;
#   in import ./tests/package-scopes.nix {
#     nixpkgs = source "nixpkgs";
#     hmStable = source "hm-stable";
#   }'
{
  nixpkgs,
  hmStable,
  system ? "x86_64-linux",
}:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  inherit (pkgs) lib;
  packageOption = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
  };
  rolePackages =
    role:
    (lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        ../modules/core/roles.nix
        ../modules/role-desktop.nix
        ../modules/role-server.nix
        {
          options.environment.systemPackages = packageOption;
          config = {
            _module.check = false;
            sys.role = {
              desktop.enable = role == "desktop";
              server.enable = role == "server";
            };
          };
        }
      ];
    }).config.environment.systemPackages;
  # Follow the real HM loader so the shared package file must actually load.
  sharedPackages =
    (lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        { options.home.packages = packageOption; }
      ]
      ++
        lib.filter (path: builtins.baseNameOf path == "packages.nix")
          (import ../hm-loader.nix { inherit lib; }).imports;
    }).config.home.packages;
  has = name: packages: lib.any (package: lib.getName package == name) packages;
in
{
  composition = import ./home-composition.nix { inherit pkgs hmStable; };
  containers = import ./home-container-optout.nix { inherit pkgs hmStable; };
  terminal = import ./terminal-options.nix { inherit pkgs hmStable; };
  packages = {
    desktopGetsAsdf = has "asdf-vm" (rolePackages "desktop");
    serverDoesNotGetAsdf = !(has "asdf-vm" (rolePackages "server"));
    noRoleDoesNotGetAsdf = !(has "asdf-vm" (rolePackages null));
    sharedDupeKrillNeedsNoSwitch = has "dupe-krill" sharedPackages;
  };
}
