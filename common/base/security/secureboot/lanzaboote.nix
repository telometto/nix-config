{ config, inputs, lib, pkgs, ... }:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  environment.systemPackages = with pkgs; [
    sbctl
    # lanzaboote-tool # Required for Secure Boot
  ];
}
