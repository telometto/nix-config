# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.tailscale = {
    extraUpFlags = [
      "--ssh"
#      "--accept-routes"
    ];
  };
}
