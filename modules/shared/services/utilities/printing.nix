# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.printing = {
    enable = false; # Default: true
  };
}
