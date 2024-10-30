{ config, inputs, lib, pkgs, ... }:

{
  imports = [ inputs.disko.nixosModules.disko ];
}
