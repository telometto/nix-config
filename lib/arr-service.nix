name:
{ lib, config, ... }:
let
  cfg = config.sys.services.${name};
  spec = (import ./arr-services.nix).${name};
  traefikLib = import ./traefik.nix { inherit lib; };
in
{
  options.sys.services.${name} = {
    enable = lib.mkEnableOption spec.title;

    port = lib.mkOption {
      type = lib.types.port;
      default = spec.port;
      description = "Port where ${spec.title} listens.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${name}";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    reverseProxy = traefikLib.mkReverseProxyOptions { inherit name; };
  };

  config = lib.mkIf cfg.enable {
    services = {
      ${name} = {
        enable = true;
        inherit (cfg) dataDir openFirewall;
      }
      // lib.setAttrByPath (spec.portOption or [
        "settings"
        "server"
        "port"
      ]
      ) cfg.port;

      traefik.dynamic.files.${name} = traefikLib.mkTraefikDynamicConfig {
        inherit name cfg config;
        inherit (cfg) port;
      };
    };

    # Volume-mounted state requires a stable account and shared media group.
    systemd.services.${name}.serviceConfig = {
      DynamicUser = lib.mkForce false;
      SupplementaryGroups = [ "users" ];
      UMask = lib.mkForce "002";
    };

    assertions = [ (traefikLib.mkCfTunnelAssertion { inherit name cfg; }) ];
  };
}
