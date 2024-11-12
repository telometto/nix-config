# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  virtualisation = {
    containers = {
      storage = {
        settings = {
          storage = {
            driver = "overlay"; # Sets the storage driver to overlay
          };
        };
      };
    };
  };
}
