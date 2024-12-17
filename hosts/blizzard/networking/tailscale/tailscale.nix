# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.tailscale = {
    extraUpFlags = [
      "--ssh"
      "--advertise-routes=192.168.2.0/24"
    ];
  };
}
