{ config, inputs, lib, pkgs, myVars, ... }:

{
  imports = [ inputs.sops-nix.agenix.nixosModules.sops ];

  #sops = {
  #  defaultSopsFile = "";
  #  defaultSopsFormat = "yaml";
  #  
  #};
}
