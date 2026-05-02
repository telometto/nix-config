{ lib, config, ... }:
let
  cfg = config.sys.networking.networkmanager;
in
{
  options.sys.networking.networkmanager = {
    enable = lib.mkEnableOption "NetworkManager service";
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.sys.networking.networkd.enable;
        message = "sys.networking.networkmanager.enable and sys.networking.networkd.enable are mutually exclusive - enable only one.";
      }
    ];

    networking = {
      networkmanager = {
        enable = lib.mkDefault true;
        dns = lib.mkDefault "systemd-resolved";

        connectionConfig = {
          "connection.mdns" = 2; # Enable mDNS
          "ipv4.dns-priority" = -100; # Prefer DHCP DNS but allow fallback
          "ipv6.dns-priority" = -100;
        };
      };
      useNetworkd = lib.mkForce false;
      useDHCP = lib.mkDefault true;
    };
    systemd.network.enable = lib.mkForce false;

  };
}
