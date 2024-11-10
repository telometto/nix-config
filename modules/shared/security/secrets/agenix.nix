{ config, inputs, lib, pkgs, myVars, ... }:

{
  imports = [ inputs.agenix.nixosModules.default ];

  #age.identityPaths = [
  #  "/home/${myVars.mainUsers.server.user}/secrets/mySecret.age"
  #];

  environment.systemPackages = [ inputs.agenix.packages."${myVars.general.system}".default ];
}
