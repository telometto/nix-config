{
  lib,
  config,
  pkgs,
  VARS,
  ...
}:
let
  cfg = config.sys.services.adguardhome;
in
{
  options.sys.services.adguardhome = {
    enable = lib.mkEnableOption "AdGuard Home DNS filter and ad blocker";

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "IP address for the web interface to listen on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for the AdGuard Home web interface";
    };

    dnsPort = lib.mkOption {
      type = lib.types.port;
      default = 53;
      description = "Port for DNS service";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for AdGuard Home web interface and DNS ports";
    };

    mutableSettings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow changes made in the web UI to persist between restarts";
    };

    disableSystemdResolved = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically disable systemd-resolved's stub listener and DNSSEC validation
        to prevent conflicts with AdGuard Home. AdGuard Home will handle DNSSEC instead.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "AdGuard Home configuration settings passed directly to the upstream NixOS module. No defaults are provided by this wrapper; AdGuard Home's built-in defaults will be used unless explicitly overridden.";
      example = lib.literalExpression ''
        {
          dns.upstream_dns = [ "1.1.1.1" "9.9.9.9" ];
          filtering.protection_enabled = true;
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.adguardhome = {
      enable = true;
      inherit (cfg)
        host
        port
        openFirewall
        mutableSettings
        ;
      settings = lib.recursiveUpdate { dns.port = cfg.dnsPort; } cfg.settings;
    };

    sys.services.resolved = lib.mkIf cfg.disableSystemdResolved {
      enable = lib.mkForce false;
    };

    services.resolved = lib.mkIf cfg.disableSystemdResolved {
      enable = true;

      settings.Resolve = {
        DNSStubListener = "no";
        DNSSEC = "false";
        LLMNR = "true";
      };
    };

    networking.nameservers = lib.mkIf cfg.disableSystemdResolved [ "127.0.0.1" ];
  };
}
