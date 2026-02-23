{ lib, config, ... }:
let
  cfg = config.sys.services.timesyncd;
in
{
  options.sys.services.timesyncd.enable = lib.mkEnableOption "systemd-timesyncd";

  config = lib.mkIf cfg.enable {
    services.timesyncd = {
      enable = lib.mkDefault true;

      servers = lib.mkDefault [
        "time.cloudflare.com"
        "0.no.pool.ntp.org"
        "1.no.pool.ntp.org"
        "2.no.pool.ntp.org"
        "3.no.pool.ntp.org"
      ];

      fallbackServers = lib.mkDefault [
        "0.nixos.pool.ntp.org"
        "1.nixos.pool.ntp.org"
        "2.nixos.pool.ntp.org"
        "3.nixos.pool.ntp.org"
      ];
    };
  };
}
