{ config, pkgs, lib, pkgs-stable, ... }:

{
  nixpkgs.overlays = [
    # Overlay: Use `self` and `super` to express
    # the inheritance relationship
    (self: super: {
      jamesdsp = pkgs-stable.jamesdsp;
    })
  ];
}
