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

      allowedTCPPorts = [
        # Start of NFS ports
        111
        2049 # NFSv4
        4000 # statd
        4001 # lockd
        4002 # mountd
        20048
        # End of NFS ports

        # Services
        28981 # Paperless
      ];

      allowedUDPPorts = allowedTCPPorts;
    };

    nftables = { enable = false; }; # Use nftables instead of iptables
  };
}
