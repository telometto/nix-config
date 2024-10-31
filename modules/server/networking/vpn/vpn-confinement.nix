{ config, inputs, lib, pkgs, ... }:

{
  imports = [ inputs.vpn-confinement.nixosModules.default ];
}
