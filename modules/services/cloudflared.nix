{
  lib,
  config,
  ...
}:
let
  cfg = config.sys.services.cloudflared;
in
{
  options.sys.services.cloudflared = {
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

    originRequest = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Global origin request options applied to all ingress rules.
        See https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/local-management/ingress/#origin-configuration
      '';
      example = {
        noTLSVerify = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.cloudflared = {
      enable = lib.mkDefault true;

      tunnels.${cfg.tunnelId} = {
        inherit (cfg) credentialsFile ingress;
        default = lib.mkDefault "http_status:404";
      }
      // lib.optionalAttrs (cfg.originRequest != { }) {
        inherit (cfg) originRequest;
      };
    };
  };
}
