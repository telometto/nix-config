{ config, lib, pkgs, ... }:

{
  # Enable USB support.
  services = {
    gvfs = {
      enable = true;
    };

    udisks2 = {
      enable = true;
    };
  };
}
