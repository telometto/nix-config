# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.atuin = {
    enable = true;
  };
}
