{
  lib,
  config,
  ...
}:
let
  cfg = config.telometto.services.cloudflared;
in
{
  options.telometto.services.cloudflared = {
    enable = lib.mkEnableOption "Cloudflare Tunnel";

    tunnelId = lib.mkOption {
      type = lib.types.str;
      description = "Cloudflare Tunnel ID";
    };

    credentialsFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to tunnel credentials file (use sops.secrets.*.path)";
    };

    ingress = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Ingress rules - see Cloudflare Tunnel documentation";
      example = {
        "grafana.example.com" = "http://localhost:3000";
        "*.example.com" = "http://localhost:8080";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.cloudflared = {
      enable = true;
      tunnels.${cfg.tunnelId} = {
        inherit (cfg) credentialsFile ingress;
        default = "http_status:404";
      };
    };
  };
}
