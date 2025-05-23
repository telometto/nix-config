{ config, lib, pkgs, ... }:

{
  networking = {
    useNetworkd = lib.mkDefault false; # Default: false
    useDHCP = lib.mkDefault true; # Defaults to true; disabled for systemd-networkd
  };

  systemd.network = {
    enable = lib.mkDefault false; # Default: to false
    wait-online.enable = lib.mkDefault true;
  };

  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    dnsovertls = "opportunistic";
    llmnr = "true";
  };
}
