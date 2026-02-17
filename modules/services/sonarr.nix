{ lib, config, ... }:
let
  cfg = config.sys.services.sonarr or { };
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.sonarr = {
    enable = lib.mkEnableOption "Sonarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8989;
      description = "Port where Sonarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sonarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "sonarr"; };
  };

  config = lib.mkIf cfg.enable {
    services.sonarr = {
      enable = true;
      inherit (cfg) dataDir openFirewall;
      settings.server.port = cfg.port;
    };

    # Disable DynamicUser to prevent conflict with volume-mounted dataDir
    systemd.services.sonarr.serviceConfig = {
      DynamicUser = lib.mkForce false;
      SupplementaryGroups = [ "users" ];
      UMask = "002";
    };

    services.traefik.dynamic.files.sonarr = traefikLib.mkTraefikDynamicConfig {
      name = "sonarr";
      inherit cfg config;
      inherit (cfg) port;
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion {
        name = "sonarr";
        inherit cfg;
      })
    ];
  };
}
