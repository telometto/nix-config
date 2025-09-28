# Enabled (role)
{ lib, config, pkgs, ... }:
let cfg = config.telometto.boot.lanzaboote;
in {
  options.telometto.boot.lanzaboote.enable = lib.mkEnableOption "Secure Boot";

  config = lib.mkIf cfg.enable {
    boot = {
      loader.systemd-boot.enable =
        lib.mkForce false; # ensure disabled when lanzaboote is on

      lanzaboote = {
        enable = lib.mkDefault true;
        pkiBundle = lib.mkDefault "/etc/secureboot";
      };
    };

    environment.systemPackages = [ pkgs.sbctl ];
  };
}
