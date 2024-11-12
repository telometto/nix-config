{ config, lib, pkgs, myVars, ... }:

{
  networking = {
    hostName = myVars.server.hostname;
    hostId = myVars.server.hostId;

    wireless = { enable = false; }; # Enables wireless support via wpa_supplicant.
    networkmanager = { enable = false; }; # Easiest to use and most distros use this by default.

    # Firewall-related
    firewall = rec {
      enable = true;

      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = [ ];

      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };

    nftables = { enable = false; }; # Use nftables instead of iptables
  };
}
