/**
 * This Nix expression configures systemd-networkd for a desktop system.
 * It sets up a network interface with DHCP and IPv6 privacy extensions enabled.
 *
 * The configuration includes:
 * - `INTERFACE`: The name of the network interface to configure.
 * - `systemd.network.networks`: A set of network configurations for systemd-networkd.
 * - `40-${INTERFACE}`: The network configuration for the specified interface.
 *     - `matchConfig.Name`: Matches the network interface by name.
 *     - `networkConfig`: Network settings for the interface.
 *       - `DHCP`: Enables DHCP for the interface.
 *       - `IPv6PrivacyExtensions`: Enables IPv6 privacy extensions.
 *       - `#IPv6AcceptRA`: (Commented out) Option to accept IPv6 Router Advertisements.
 *       - `#LinkLocalAddressing`: (Commented out) Option to disable link-local addressing, useful for VLANs.
 *     - `linkConfig`: Link settings for the interface.
 *       - `RequiredForOnline`: Sets the interface to be required for the system to be considered online.
 */

{ config, lib, pkgs, ... }:

let
  INTERFACE = "enp5s0";
in
{
  systemd.network = {
    networks = {
      "40-${INTERFACE}" = {
        matchConfig.Name = INTERFACE;

        networkConfig = {
          DHCP = "yes";
          IPv6PrivacyExtensions = "kernel";
          #IPv6AcceptRA = true;
          #LinkLocalAddressing = "no"; # VLAN
        };

        linkConfig = {
          RequiredForOnline = "routable";
        };
      };
    };
  };
}
