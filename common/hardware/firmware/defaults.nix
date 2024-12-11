/**
 * This NixOS module configuration enables the `fwupd` service and adds `fwupd` to the system packages.
 * `fwupd` is a daemon for managing the installation of firmware updates.
 * 
 * - `services.fwupd.enable = true;` enables the `fwupd` service.
 * - `environment.systemPackages` adds `fwupd` to the list of system packages, making it available for use.
*/

{ config, lib, pkgs, ... }:

{
  services.fwupd = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [ fwupd ];
}
