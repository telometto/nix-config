# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.tailscale = {
    extraUpFlags = [
      "--reset"
      "--ssh"
      "--advertise-routes=192.168.2.0/24"
    ];
  };
}
