{ lib, config, ... }:
let
  cfg = config.sys.services.readarr or { };
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.readarr = {
    enable = lib.mkEnableOption "Readarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "Port where Readarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/readarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "readarr"; };
  };

  config = lib.mkIf cfg.enable {
    services.readarr = {
      enable = true;
      inherit (cfg) dataDir openFirewall;
      settings.server.port = cfg.port;
    };

    # Disable DynamicUser to prevent conflict with volume-mounted dataDir
    systemd.services.readarr.serviceConfig = {
      DynamicUser = lib.mkForce false;
      SupplementaryGroups = [ "users" ];
      UMask = "002";
    };

    services.traefik.dynamic.files.readarr = traefikLib.mkTraefikDynamicConfig {
      name = "readarr";
      inherit cfg config;
      port = cfg.port;
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion { name = "readarr"; inherit cfg; })
    ];
  };
}
