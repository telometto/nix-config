{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.cloudflare-warp;
in
{
  options.telometto.services.cloudflare-warp = {
    enable = lib.mkEnableOption "Cloudflare WARP (Zero Trust client)";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open the UDP port in the firewall.";
    };

    # udpPort = lib.mkOption {
    #   type = lib.types.port;
    #   default = 2408;
    #   description = ''
    #     The UDP port to open in the firewall. WARP uses port 2408 by default,
    #     but fallback ports (500, 1701, 4500) can be used if that conflicts
    #     with another service.
    #   '';
    # };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra attributes merged into services.cloudflare-warp.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.cloudflare-warp = lib.mkMerge [
      {
        enable = lib.mkDefault true;
        inherit (cfg) openFirewall;
      }
      cfg.settings
    ];

    environment.systemPackages = [ ];
  };
}
