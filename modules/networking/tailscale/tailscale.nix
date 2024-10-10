# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = "/opt/sec/ts-file";
      
    # Requires authKeyFile to be set
    extraUpFlags = [
      "--ssh"
      "--advertise-routes=192.168.7.0/24"
    ];
  };
}
