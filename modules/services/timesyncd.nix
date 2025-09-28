# OK
{ lib, config, ... }:
let cfg = config.telometto.services.timesyncd;
in {
  options.telometto.services.timesyncd.enable =
    lib.mkEnableOption "systemd-timesyncd";
  config = lib.mkIf cfg.enable {
    services.timesyncd = {
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
