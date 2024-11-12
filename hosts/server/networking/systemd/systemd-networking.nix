# Does not work.
{ config, lib, pkgs, ... }:

{
  systemd.network = {
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
