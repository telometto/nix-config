# OK
{ lib, config, ... }:
let
  cfg = config.sys.services.resolved or { };
in
{
  options.sys.services.resolved.enable = (lib.mkEnableOption "systemd-resolved") // {
    default = true;
  };

  options.sys.services.resolved = {
    DNS = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "DNS servers to use (can be overridden per-host).";
  };

  extraSettings = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Extra settings merged into services.resolved (owner extension point).";
  };};

  config = lib.mkIf cfg.enable {
    services.resolved = lib.mkMerge [
      {
        enable = true;

        settings = {
          Resolve = {
            DNSOverTLS = "opportunistic";
            DNSSEC = "allow-downgrade";
            LLMNR = "true";

            inherit (cfg) DNS;

            FallbackDNS = [
              "1.1.1.1#cloudflare-dns.com"
              "9.9.9.9#dns.quad9.net"
            ];
          };
        };
      }
      cfg.extraSettings
    ];
  };
}
