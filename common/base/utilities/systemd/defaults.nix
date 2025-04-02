{ config, lib, pkgs, ... }:

{
  services.systemd = {
    # homed.enable = true;

    timesyncd = {
      enable = true;

      servers = [
        "time.cloudflare.com"
        "0.no.pool.ntp.org"
        "1.no.pool.ntp.org"
        "2.no.pool.ntp.org"
        "3.no.pool.ntp.org"
      ];

      fallbackServers = [
        "0.nixos.pool.ntp.org"
        "1.nixos.pool.ntp.org"
        "2.nixos.pool.ntp.org"
        "3.nixos.pool.ntp.org"
      ];
    };
  };
}