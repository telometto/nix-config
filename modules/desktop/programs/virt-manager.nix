# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  programs.virt-manager = {
    enable = true;
  };

  # environment.systemPackages = with pkgs; [ steam ];
}
