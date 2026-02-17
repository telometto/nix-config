{ lib, config, ... }:
let
  cfg = config.sys.services.overseerr or { };
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.overseerr = {
    enable = lib.mkEnableOption "Overseerr";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
      description = "Port where Overseerr listens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "overseerr"; };
  };

  config = lib.mkIf cfg.enable {
    services.overseerr = {
      enable = true;
      inherit (cfg) port openFirewall;
    };

    services.traefik.dynamic.files.overseerr = traefikLib.mkTraefikDynamicConfig {
      name = "overseerr";
      inherit cfg config;
      port = cfg.port;
    };

    assertions = [
      (traefikLib.mkCfTunnelAssertion { name = "overseerr"; inherit cfg; })
    ];
  };
}
