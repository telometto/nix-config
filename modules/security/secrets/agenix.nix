{ config, inputs, lib, pkgs, ... }:

{
  imports = [ inputs.agenix.nixosModules.default ];

  #age.identityPaths = [
  #  "/home/${}/secrets/mySecret.age"
  #];

  environment.systemPackages = [ inputs.agenix.packages."x86_64-linux".default ];
}
