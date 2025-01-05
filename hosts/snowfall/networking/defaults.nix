{ config, lib, pkgs, VARS, ... }:
let
  INTERFACE = "enp5s0";
in
{
  networking = {
    inherit (VARS.systems.desktop) hostName hostId;

    wireless = { enable = false; }; # Enables wireless support via wpa_supplicant.
    networkmanager = { enable = true; }; # Easiest to use and most distros use this by default.

    # Firewall-related
    firewall = rec {
      enable = true;

      allowedTCPPortRanges = [
        { from = 1714; to = 1764; } # Required by KDE Connect
      ];

      allowedUDPPortRanges = allowedTCPPortRanges;
    };

    nftables = { enable = false; }; # Use nftables instead of iptables

    useNetworkd = lib.mkForce false;
    useDHCP = lib.mkForce true;
  };

  ## Not in use, due to networkmanager being enabled and compatibility with certain VPNs.
  ## Here for reference.
  # systemd.network = {
  #   enable = lib.mkForce true;

  #   wait-online.enable = lib.mkForce false;

  #   networks = {
  #     "40-${INTERFACE}" = {
  #       matchConfig.Name = INTERFACE;

  #       networkConfig = {
  #         DHCP = "yes";
  #         IPv6PrivacyExtensions = "kernel";
  #         #IPv6AcceptRA = true;
  #         #LinkLocalAddressing = "no"; # VLAN
  #       };

  #       linkConfig = {
  #         RequiredForOnline = "routable";
  #       };
  #     };
  #   };
  # };
}
