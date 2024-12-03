/**
 * This NixOS module configures the Tailscale service with default settings.
 * It enables the Tailscale service, opens the firewall for Tailscale traffic,
 * and specifies the path to the Tailscale authentication key file.
 * Additionally, it ensures that the Tailscale package is included in the system environment packages.
 *
 * - authKeyFile: The path to the Tailscale authentication key file.
 */

{ config, lib, pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets."general/tsKeyFilePath".path;
  };

  environment.systemPackages = with pkgs; [ tailscale ];
}
