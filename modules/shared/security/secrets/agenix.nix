{ config, inputs, lib, pkgs, ... }:

{
  imports = [ inputs.agenix.nixosModules.default ];

  environment.systemPackages = [ inputs.agenix.packages."${system}".default ];
}
