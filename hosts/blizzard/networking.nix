{ lib, config, ... }:
{
  systemd.network = {
    enable = lib.mkForce true;
    wait-online.enable = lib.mkForce true;

    networks."40-enp8s0" = {
      matchConfig.Name = "enp8s0";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
        IPv6PrivacyExtensions = "kernel";
      };

      dhcpV4Config = {
        UseDNS = true;
        UseRoutes = true;
        RouteMetric = 100;
      };

      dhcpV6Config = {
        UseDNS = true;
      };

      linkConfig.RequiredForOnline = "routable";
    };
  };

  services.tailscale.permitCertUid = lib.mkIf config.services.traefik.enable "traefik";
}
