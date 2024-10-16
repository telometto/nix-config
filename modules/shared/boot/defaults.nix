# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  # Bootloader
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;

      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
    };

    kernel = {
      sysctl = {
        "net.core.wmem_max" = 7500000; # for cloudflared tunnel
        "net.core.rmem_max" = 7500000; # for cloudflared tunnel

        "net.ipv4.ip_forward" = 1; # tailscale optimization: enable ipv4 forwarding
        "net.ipv6.conf.all.forwarding" = 1; # tailscale optimization: enable ipv6 forwarding
      };
    };
  };
}
