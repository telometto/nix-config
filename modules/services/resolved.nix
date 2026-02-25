{ lib, config, ... }:
let
  cfg = config.sys.services.resolved;
  resolveSettings = lib.filterAttrs (_: v: v != null) {
    DNS = if cfg.enableDNS then cfg.DNS else null;
    FallbackDNS = if cfg.enableFallbackDNS then cfg.FallbackDNS else null;
    DNSSEC = if cfg.enableDNSSEC then cfg.DNSSEC else null;
    DNSOverTLS = if cfg.enableDNSOverTLS then cfg.DNSOverTLS else null;
    LLMNR = if cfg.enableLLMNR then cfg.LLMNR else null;
  };
in
{
  options.sys.services.resolved = {
    enable = (lib.mkEnableOption "systemd-resolved") // {
      default = true;
    };

    enableDNS = lib.mkEnableOption "custom DNS servers";
    DNS = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "DNS servers to use. Only applied when enableDNS is true.";
    };

    enableFallbackDNS = lib.mkEnableOption "custom fallback DNS servers";
    FallbackDNS = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "9.9.9.9#dns.quad9.net"
        "1.1.1.1#cloudflare-dns.com"
      ];
      description = "Fallback DNS servers to use. Only applied when enableFallbackDNS is true.";
    };

    enableDNSSEC = lib.mkEnableOption "explicit DNSSEC configuration";
    DNSSEC = lib.mkOption {
      type = lib.types.str;
      default = "allow-downgrade";
      description = "DNSSEC validation mode (e.g. 'true', 'false', 'allow-downgrade'). Only applied when enableDNSSEC is true.";
    };

    enableDNSOverTLS = lib.mkEnableOption "explicit DNS-over-TLS configuration";
    DNSOverTLS = lib.mkOption {
      type = lib.types.str;
      default = "opportunistic";
      description = "DNS-over-TLS mode (e.g. 'true', 'false', 'opportunistic'). Only applied when enableDNSOverTLS is true.";
    };

    enableLLMNR = lib.mkEnableOption "explicit LLMNR configuration";
    LLMNR = lib.mkOption {
      type = lib.types.str;
      default = "true";
      description = "LLMNR mode (e.g. 'true', 'false', 'resolve'). Only applied when enableLLMNR is true.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra settings merged into services.resolved (owner extension point).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.resolved = lib.mkMerge [
      {
        enable = true;
        settings.Resolve = lib.mkIf (resolveSettings != { }) resolveSettings;
      }
      cfg.extraSettings
    ];
  };
}
