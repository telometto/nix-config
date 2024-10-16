{ config, inputs, lib, pkgs, ... }:

{
  imports = [
    inputs.agenix.nixosModules.default
  ];
}
