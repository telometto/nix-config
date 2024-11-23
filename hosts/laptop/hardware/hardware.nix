{ config, inputs, lib, pkgs, ... }:

{
  imports = [ inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p51 ];
}
