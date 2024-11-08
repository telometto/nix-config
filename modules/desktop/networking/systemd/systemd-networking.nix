# Does not work.
{ config, lib, pkgs, ... }:

{
  systemd.network = {
    networks = {
      "40-enp5s0" = {
        matchConfig.Name = "enp5s0";

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
