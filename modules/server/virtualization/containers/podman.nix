# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  virtualisation = {
    containers = {
      storage = {
        settings = {
          storage = {
            driver = "zfs"; # Sets the storage driver to zfs
          };
        };
      };
    };
  };
}
