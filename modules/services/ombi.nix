{ lib, config, ... }:
let
  cfg = config.sys.services.ombi or { };
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.ombi = {
    enable = lib.mkEnableOption "Ombi";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Port where Ombi listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/ombi";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "ombi"; };
  };

  config = lib.mkIf cfg.enable {
    services.ombi = {
      enable = true;
      inherit (cfg) dataDir openFirewall port;
    };

    services.traefik.dynamic.files.ombi = traefikLib.mkTraefikDynamicConfig {
      name = "ombi";
      inherit cfg config;
      inherit (cfg) port;
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion {
        name = "ombi";
        inherit cfg;
      })
    ];
  };
}
