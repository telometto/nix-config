{ config, lib, pkgs, VARS, ... }:
let
  INTERFACE = "enp8s0";
in
{
  networking = {
    hostName = VARS.systems.server.hostname;
    hostId = VARS.systems.server.hostId;

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

    ## Related to systemd-networkd
    vlans = {
      vlan4 = {
        id = 4;
        interface = INTERFACE;
      };
    };

    interfaces.vlan4.ipv4.addresses = [{
      address = "192.168.4.100";
      prefixLength = 24;
    }];

    useNetworkd = lib.mkForce true;
    # useDHCP = lib.mkForce false;
  };

  systemd.network = {
    enable = lib.mkForce true;

    wait-online.enable = lib.mkForce true;

    networks = {
      "40-enp8s0" = {
        matchConfig.Name = INTERFACE;

        networkConfig = {
          DHCP = "yes";
          IPv6PrivacyExtensions = "kernel";
          LinkLocalAddressing = "no"; # VLAN
        };

        vlan = [ "vlan4" ]; # VLAN

        linkConfig = {
          RequiredForOnline = "carrier";
        };
      };

      "40-vlan4" = {
        matchConfig.Name = "vlan4";
      };
    };

    netdevs = {
      "40-vlan4" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan4";
        };

        vlanConfig.Id = 4;
      };
    };
  };
}
