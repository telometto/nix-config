# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  programs.gnupg = {
    agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  environment.systemPackages = with pkgs; [ gnupg ];
}
