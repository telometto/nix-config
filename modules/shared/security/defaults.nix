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

  environment.systemPackages = with pkgs; [
    # apparmor-related packages
    apparmor-bin-utils
    apparmor-kernel-patches
    apparmor-pam
    apparmor-parser
    apparmor-profiles
    apparmor-utils
    libapparmor

    # polkit-related packages
    polkit
  ];
}
