{ lib, config, ... }:
let
  cfg = config.sys.services.bazarr or { };
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.bazarr = {
    enable = lib.mkEnableOption "Bazarr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 6767;
      description = "Port where Bazarr listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/bazarr";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "bazarr"; };
  };

  config = lib.mkIf cfg.enable {
    services = {
      bazarr = {
        enable = true;
        listenPort = cfg.port;
        inherit (cfg) dataDir openFirewall;
      };

      traefik.dynamic.files.bazarr = traefikLib.mkTraefikDynamicConfig {
        name = "bazarr";
        inherit cfg config;
        inherit (cfg) port;
      };
    };

    # Disable DynamicUser to prevent conflict with volume-mounted dataDir
    systemd.services.bazarr.serviceConfig = {
      DynamicUser = lib.mkForce false;
      SupplementaryGroups = [ "users" ];
      UMask = lib.mkForce "002";
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion {
        name = "bazarr";
        inherit cfg;
      })
    ];
  };
}
