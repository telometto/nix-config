/**
 * This Nix module configures systemd networking for a NixOS system.
 * It evaluates whether networkmanager is enabled based on the current configuration.
 * If it isn't, it enables systemd-networkd and DHCP accordingly.
 *
 * NOTE: It checks whether networkmanager is enabled at the time of evaluation; not
 * based on the current state of the host system.
 *
 * Additionally, it sets up systemd-resolved with specific DNS settings.
 *
 * Configuration:
 * - `networking.useNetworkd`: Enables systemd-networkd if NetworkManager is disabled.
 * - `networking.useDHCP`: Disables DHCP if systemd-networkd is enabled.
 * - `systemd.network.enable`: Enables systemd-networkd.
 * - `services.resolved.enable`: Enables systemd-resolved.
 * - `services.resolved.dnssec`: Sets DNSSEC mode to "allow-downgrade".
 * - `services.resolved.dnsovertls`: Sets DNS over TLS mode to "opportunistic".
 * - `services.resolved.llmnr`: Enables Link-Local Multicast Name Resolution (LLMNR).
 */

{ config, lib, pkgs, ... }:

let
  enableSystemdNetworking = !config.networking.networkmanager.enable;
in
{
  networking = {
    useNetworkd = enableSystemdNetworking; # Defaults to false
    useDHCP = !enableSystemdNetworking; # Defaults to true; disabled for systemd-networkd
  };

  systemd.network = {
    enable = enableSystemdNetworking; # Defaults to false
  };

  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    dnsovertls = "opportunistic";
    llmnr = "true";
  };
}
