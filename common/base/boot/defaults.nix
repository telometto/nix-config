/**
 * This NixOS configuration file sets up the bootloader and kernel parameters.
 * It enables the systemd-boot bootloader with a limit of 10 configurations and allows
 * touching EFI variables. It also configures the kernel to support NFS filesystems and
 * sets specific sysctl parameters for network performance optimization, particularly
 * for cloudflared tunnels. Additionally, it includes necessary system packages for NFS support.
 */

{ config, lib, pkgs, VARS, ... }:
let
  MEM_MAX = 7500000;
in
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

    supportedFilesystems = [ "nfs" ];

    kernel = {
      sysctl = {
        "net.core.wmem_max" = MEM_MAX; # For cloudflared tunnel
        "net.core.rmem_max" = MEM_MAX; # For cloudflared tunnel

        # "net.ipv4.ip_forward" = 1; # Tailscale optimization: enable ipv4 forwarding
        # "net.ipv6.conf.all.forwarding" = 1; # Tailscale optimization: enable ipv6 forwarding
      };
    };
  };

  environment.systemPackages = with pkgs; [
    libnfs
    nfs-utils
  ];
}
