{
  lib,
  config,
  ...
}:
let
  cfg = config.sys.services.glance;
  traefikLib = import ../../lib/traefik.nix { inherit lib; };
in
{
  options.sys.services.glance = {
    enable = lib.mkEnableOption "Glance dashboard";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address where Glance listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port where Glance listens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a Glance environment file.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra Glance settings written to the generated YAML configuration.";
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { name = "glance"; };
  };

  config = lib.mkIf cfg.enable {
    services.glance = {
      enable = true;
      environmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
      settings = lib.recursiveUpdate {
        server = {
          inherit (cfg) host port;
        }
        // lib.optionalAttrs cfg.reverseProxy.enable {
          proxied = true;
        };
      } cfg.settings;
    };

    services.traefik.dynamic.files.glance = traefikLib.mkTraefikDynamicConfig {
      name = "glance";
      inherit cfg config;
      inherit (cfg) port;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    assertions = [
      {
        assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.domain != null;
        message = "sys.services.glance.reverseProxy.domain must be set when reverseProxy is enabled";
      }
      {
        assertion = !cfg.reverseProxy.cfTunnel.enable || cfg.reverseProxy.enable;
        message = "sys.services.glance.reverseProxy.enable must be true when cfTunnel.enable is true";
      }
      (traefikLib.mkCfTunnelAssertion {
        name = "glance";
        inherit cfg;
      })
    ];
  };
}
