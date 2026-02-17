{ lib, config, ... }:
let
  cfg = config.sys.services.prowlarr or { };
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.prowlarr = {
    enable = lib.mkEnableOption "Prowlarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9696;
      description = "Port where Prowlarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/prowlarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "prowlarr"; };
  };

  config = lib.mkIf cfg.enable {
    services.prowlarr = {
      enable = true;
      inherit (cfg) dataDir openFirewall;
      settings.server.port = cfg.port;
    };

    # Disable DynamicUser to prevent conflict with volume-mounted dataDir
    systemd.services.prowlarr.serviceConfig = {
      DynamicUser = lib.mkForce false;
      SupplementaryGroups = [ "users" ];
      UMask = "002";
    };

    services.traefik.dynamic.files.prowlarr = traefikLib.mkTraefikDynamicConfig {
      name = "prowlarr";
      inherit cfg config;
      port = cfg.port;
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion { name = "prowlarr"; inherit cfg; })
    ];
  };
}
