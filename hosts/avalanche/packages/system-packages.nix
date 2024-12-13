# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    microcodeIntel # Intel CPU microcode updates
  ];
}
