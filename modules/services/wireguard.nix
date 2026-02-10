{ lib, config, pkgs, ... }:
let
  cfg = config.sys.services.wireguard;
  interfaceName = cfg.interface;
  wgInterface = {
    address = cfg.addresses;
    listenPort = cfg.listenPort;
    privateKeyFile = cfg.privateKeyFile;
    peers = cfg.peers;
  }
  // lib.optionalAttrs (cfg.mtu != null) { mtu = cfg.mtu; }
  // lib.optionalAttrs (cfg.preUp != "") { preUp = cfg.preUp; }
  // lib.optionalAttrs (cfg.postUp != "") { postUp = cfg.postUp; }
  // lib.optionalAttrs (cfg.preDown != "") { preDown = cfg.preDown; }
  // lib.optionalAttrs (cfg.postDown != "") { postDown = cfg.postDown; }
  // lib.optionalAttrs (cfg.dns != [ ]) { dns = cfg.dns; };
in
{
  options.sys.services.wireguard = {
    enable = lib.mkEnableOption "WireGuard (wg-quick)";

    interface = lib.mkOption {
      type = lib.types.str;
      default = "wg0";
    };

    addresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "IP addresses to assign to the WireGuard interface.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 51820;
    };

    mtu = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to WireGuard private key file.";
    };

    peers = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          publicKey = lib.mkOption { type = lib.types.str; };
          allowedIPs = lib.mkOption { type = lib.types.listOf lib.types.str; };
          endpoint = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
          persistentKeepalive = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; };
        };
      });
      default = [ ];
    };

    preUp = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Shell commands to run before bringing up the interface.";
    };

    postUp = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Shell commands to run after bringing up the interface.";
    };

    preDown = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Shell commands to run before bringing down the interface.";
    };

    postDown = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Shell commands to run after bringing down the interface.";
    };

    dns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.privateKeyFile != null;
        message = "sys.services.wireguard.privateKeyFile must be set when WireGuard is enabled";
      }
    ];

    networking.wg-quick.interfaces.${interfaceName} = wgInterface;

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [ cfg.listenPort ];
    };
  };
}
