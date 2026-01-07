{ lib, config, ... }:
let
  cfg = config.sys.networking.networkd;
in
{
  options.sys.networking.networkd = {
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
