{ config, lib, pkgs, VARS, ... }:
let INTERFACE = "enp5s0";
in {
  networking = {
    inherit (VARS.systems.desktop) hostName hostId;

    wireless = {
      enable = false;
    }; # Enables wireless support via wpa_supplicant.
    networkmanager = {
      enable = true;
    }; # Easiest to use and most distros use this by default.

    # Firewall-related
    firewall = rec {
      enable = true;

      allowedTCPPortRanges = [{
        # Required by KDE Connect
        from = 1714;
        to = 1764;
      }
      # {
      #   # Required for Steam LAN sharing; to be removed
      #   from = 27031;
      #   to = 27036;
      # }
      # {
      #   # Required for WC3; to be removed
      #   from = 6112;
      #   to = 6119;
      # }
        ];

      allowedUDPPortRanges = allowedTCPPortRanges;

      allowedTCPPorts = [
        # Start of NFS ports
        2049 # NFSv4
        4000 # statd
        4001 # lockd
        4002 # mountd
        20048
        # End of NFS ports

        # 27040 # Required for Steam LAN sharing; to be removed
        # 27015
        # 27020
      ];

      allowedUDPPorts = allowedTCPPorts;
    };

    nftables = { enable = false; }; # Use nftables instead of iptables

    useNetworkd = lib.mkForce false;
    useDHCP = lib.mkForce true;
  };
}
