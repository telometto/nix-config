{ lib, config, ... }:
let
  cfg = config.sys.services.seerr;
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.seerr = {
    enable = lib.mkEnableOption "Seerr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
      description = "Port where Seerr listens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "seerr"; };
  };

  config = lib.mkIf cfg.enable {
    services.seerr = {
      enable = true;
      inherit (cfg) port openFirewall;
    };

    services.traefik.dynamic.files.seerr = traefikLib.mkTraefikDynamicConfig {
      name = "seerr";
      inherit cfg config;
      inherit (cfg) port;
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion {
        name = "seerr";
        inherit cfg;
      })
    ];
  };
}
