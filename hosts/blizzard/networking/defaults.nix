{ config, lib, pkgs, VARS, ... }:
let
  INTERFACE = "enp8s0";
in
{
  networking = {
    inherit (VARS.systems.server) hostName hostId;

    wireless = { enable = false; }; # Enables wireless support via wpa_supplicant.
    networkmanager = { enable = false; }; # Easiest to use and most distros use this by default.

    # Firewall-related
    firewall = rec {
      enable = true;

      allowedTCPPortRanges = [
        {
          # NFS ports
          from = 4000;
          to = 4002;
        }
      ];
      allowedUDPPortRanges = allowedTCPPortRanges;

      allowedTCPPorts = [
        80 # HTTP
        443 # HTTPS

        # Start of NFS ports
        111
        2049 # NFSv4
        20048
        # End of NFS ports

        # Services
        28981 # Paperless
      ];

      allowedUDPPorts = allowedTCPPorts;
    };

    nftables = { enable = false; }; # Use nftables instead of iptables

    # useNetworkd = lib.mkForce true;
    useDHCP = lib.mkForce false;
  };

  systemd.network = {
    enable = lib.mkForce true;

    wait-online.enable = lib.mkForce true;

    networks = {
      "40-enp8s0" = {
        matchConfig.Name = INTERFACE;

        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
          IPv6PrivacyExtensions = "kernel";
        };

        linkConfig.RequiredForOnline = "routable";
      };
    };
  };
}
