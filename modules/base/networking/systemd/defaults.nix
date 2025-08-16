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

{
  networking = {
    useNetworkd = lib.mkDefault false; # Default: false
    useDHCP = lib.mkDefault true; # Defaults to true; disabled for systemd-networkd
    networkmanager.dns = "systemd-resolved";
  };

  systemd.network = {
    enable = lib.mkDefault false; # Default: to false
    wait-online.enable = lib.mkDefault true;
  };

  services.resolved = {
    enable = true; # lib.mkDefault true;
    dnssec = "allow-downgrade";
    dnsovertls = "opportunistic";
    llmnr = "true";
    # domains = [ "~." ];
    # fallbackDns = [
    #   "1.1.1.1"
    #   "1.0.0.1"
    #   "2606:4700:4700::1111"
    #   "2606:4700:4700::1001"
    # ];
  };
}
