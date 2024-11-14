{ config, inputs, lib, pkgs, myVars, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  #sops = {
  #  defaultSopsFile = "/home/${myVars.mainUsers.server.user}/.config/sops/gpg/secrets.yaml";
  #  defaultSopsFormat = "yaml";
  #};
}
