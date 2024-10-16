# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:

{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = myVars.general.tsKeyFile;
  };
}
