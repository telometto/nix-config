{ config, lib, pkgs, ... }:

{
  networking = {
    vlans = {
      vlan4 = {
        id = 4;
        interface = "enp8s0";
      };
    };

    interfaces.vlan4.ipv4.addresses = [{
      address = "192.168.4.100";
      prefixLength = 24;
    }];
  };
}
