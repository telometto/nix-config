# Deliberately avoid evaluating the repository flake or its private inputs.
let
  inherit (builtins.fromJSON (builtins.readFile ../../flake.lock)) nodes;
  publicPkgs =
    name:
    import (builtins.fetchTree nodes.${name}.locked) {
      system = "x86_64-linux";
      config.allowUnfree = true;
      overlays = [ ];
    };
  pkgs = publicPkgs "nixpkgs";
  masterPkgs = publicPkgs "nixpkgs-master";
in
pkgs.linkFarm "public-security-checks" [
  {
    name = "service-boundaries";
    path = import ../../tests/security-boundaries.nix { inherit pkgs masterPkgs; };
  }
  {
    name = "microvm-egress";
    path = import ../../tests/microvm-egress.nix { inherit pkgs; };
  }
]
