{ config, inputs, lib, pkgs, myVars, ... }:

{
  imports = [ inputs.agenix.nixosModules.default ];

  environment.systemPackages = [ inputs.agenix.packages."${myVars.general.system}".default ];
}
