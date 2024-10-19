{ config, lib, pkgs, myVars, ... }:

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
