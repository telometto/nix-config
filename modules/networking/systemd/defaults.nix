# Does not work.
{ config, lib, pkgs, ... }:

{
  networking = {
    useNetworkd = false;

    useDHCP = false; # Defaults to true; disabled for systemd-networkd
  };

  systemd.network = {
    enable = true; # Defaults to false

    networks = {
      "40-enp8s0" = {
        matchConfig.Name = "enp8s0";

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
#
      #  networkConfig = {
      #    DHCP = "no";
      #    IPv6PrivacyExtensions = "kernel";
      #    address = [ "192.168.4.100/24" ];
      #  };
      };
#
      #"50-tailscale" = {
      #  matchConfig.Name = "tailscale0";
#
      #  linkConfig = {
      #    ActivationPolicy = "manual";
      #    Unmanaged = "true";
      #  };
      #};
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

  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    dnsovertls = "opportunistic";
    llmnr = "true";
  };
}
