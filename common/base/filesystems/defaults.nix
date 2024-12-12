/**
 * This file is the common configuration of filesystems across all devices.
 */
{ config, lib, pkgs, VARS, ... }:

{
  services = {
    fstrim = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [ ];
}
