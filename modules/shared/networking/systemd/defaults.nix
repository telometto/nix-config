# Does not work.
{ config, lib, pkgs, ... }:

{
  networking = {
    useNetworkd = true;
    useDHCP = false; # Defaults to true; disabled for systemd-networkd
    #networkmanager.enable = false;
  };

  systemd.network = {
    enable = true; # Defaults to false
  };

  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    dnsovertls = "opportunistic";
    llmnr = "true";
  };
}
