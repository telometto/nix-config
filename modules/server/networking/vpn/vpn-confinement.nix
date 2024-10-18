{ config, inputs, lib, pkgs, ... }:

{
  imports = [
    vpn-confinement.nixosModules.default
  ];
}
