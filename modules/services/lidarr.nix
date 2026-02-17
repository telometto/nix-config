{ lib, config, ... }:
let
  cfg = config.sys.services.lidarr or { };
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.lidarr = {
    enable = lib.mkEnableOption "Lidarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8686;
      description = "Port where Lidarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/lidarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "lidarr"; };
  };

  config = lib.mkIf cfg.enable {
    services.lidarr = {
      enable = true;
      inherit (cfg) dataDir openFirewall;
      settings.server.port = cfg.port;
    };

    # Disable DynamicUser to prevent conflict with volume-mounted dataDir
    systemd.services.lidarr.serviceConfig = {
      DynamicUser = lib.mkForce false;
      SupplementaryGroups = [ "users" ];
      UMask = "002";
    };

    services.traefik.dynamic.files.lidarr = traefikLib.mkTraefikDynamicConfig {
      name = "lidarr";
      inherit cfg config;
      inherit (cfg) port;
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion { name = "lidarr"; inherit cfg; })
    ];
  };
}
