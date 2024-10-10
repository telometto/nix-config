{ config, inputs, lib, pkgs, ... }:

{
  imports = [
    inputs.microvm.nixosModules.host # For hosts
    # inputs.microvm.nixosModules.microvm # For guests
  ];
}