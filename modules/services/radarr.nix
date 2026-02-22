{ lib, config, ... }:
let
  cfg = config.sys.services.radarr or { };
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.radarr = {
    enable = lib.mkEnableOption "Radarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7878;
      description = "Port where Radarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/radarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "radarr"; };
  };

  config = lib.mkIf cfg.enable {
    services = {
      radarr = {
        enable = true;
        inherit (cfg) dataDir openFirewall;
        settings.server.port = cfg.port;
      };

      traefik.dynamic.files.radarr = traefikLib.mkTraefikDynamicConfig {
        name = "radarr";
        inherit cfg config;
        inherit (cfg) port;
      };
    };

    # Disable DynamicUser to prevent conflict with volume-mounted dataDir
    systemd.services.radarr.serviceConfig = {
      DynamicUser = lib.mkForce false;
      SupplementaryGroups = [ "users" ];
      UMask = lib.mkForce "002";
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion {
        name = "radarr";
        inherit cfg;
      })
    ];
  };
}
