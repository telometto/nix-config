{ lib, config, ... }:
let
  cfg = config.telometto.networking.networkd;
in
{
  options.telometto.networking.networkd = {
    enable = lib.mkEnableOption "systemd-networkd service";
  };
  config = lib.mkIf cfg.enable {
    networking = {
      networkmanager.enable = lib.mkForce false;
      useNetworkd = lib.mkDefault false;
      useDHCP = lib.mkForce false; # networkd typically manages DHCP itself
    };

    systemd.network = {
      enable = lib.mkDefault true;
      wait-online.enable = lib.mkDefault true;
    };
  };
}
