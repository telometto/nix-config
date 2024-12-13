# Host-specific system configuration defaults
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # System utilities
    microcodeIntel # Intel CPU microcode updates

    # Networking tools
    cloudflared # Cloudflare's DoH and DoT client
    cloudflare-dyndns # Dynamic DNS client for Cloudflare

    gcr_4 # GNOME crypto services
  ];
}
