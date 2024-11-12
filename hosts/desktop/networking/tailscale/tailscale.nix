/**
 * This NixOS module configures the Tailscale service for a specific host.
 * Tailscale is a zero-config VPN that securely connects your devices.
 * The configuration includes additional flags for the `tailscale up` command.
 *
 * - `extraUpFlags`: A list of extra flags to pass to the `tailscale up` command.
 *   - `--ssh`: Enables Tailscale SSH, allowing SSH access over Tailscale.
 *   - `--accept-routes`: (Commented out) Would allow the host to accept routes advertised by other nodes.
 */

{ config, lib, pkgs, ... }:

{
  services.tailscale = {
    extraUpFlags = [
      "--ssh"
      # "--accept-routes"
    ];
  };
}
