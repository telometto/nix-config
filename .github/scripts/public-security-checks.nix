# Deliberately avoid evaluating the repository flake or its private inputs.
let
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  inherit (lock) nodes;
  # Lock node names can belong to transitive inputs. Follow the root's edges.
  rootInputs = nodes.${lock.root}.inputs;
  publicPkgs =
    name:
    import (builtins.fetchTree nodes.${rootInputs.${name}}.locked) {
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
