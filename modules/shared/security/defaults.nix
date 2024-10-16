# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  security = {
    apparmor = {
      enable = true;
    };

    polkit = {
      enable = true;
    };

    tpm2 = {
      enable = true;
    };
  };
}
