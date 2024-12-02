{ config, lib, pkgs, myVars, ... }:

{
  networking = {
    hostName = myVars.systems.laptop.hostname;
    hostId = myVars.systems.laptop.hostId;

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

    nftables = { enable = true; }; # Use nftables instead of iptables
  };
}