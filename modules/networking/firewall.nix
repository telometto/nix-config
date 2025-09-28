{ lib, config, ... }:
let
  cfg = config.telometto.networking.firewall;
  portRangeType = lib.types.submodule ({ ... }: {
    options = {
      from = lib.mkOption {
        type = lib.types.port;
        description = "Range start";
      };
      to = lib.mkOption {
        type = lib.types.port;
        description = "Range end";
      };
    };
  });
in {
  options.telometto.networking.firewall = {
    enable = lib.mkEnableOption "Firewall base policy";
    extraTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Individual TCP ports to allow (empty by default).";
    };
    extraUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Individual UDP ports to allow (empty by default).";
    };
    extraTCPPortRanges = lib.mkOption {
      type = lib.types.listOf portRangeType;
      default = [ ];
      description =
        "TCP port ranges to allow; service modules (e.g. kdeconnect) should manage their own if openFirewall is set.";
    };
    extraUDPPortRanges = lib.mkOption {
      type = lib.types.listOf portRangeType;
      default = [ ];
      description =
        "UDP port ranges to allow; service modules handle theirs when openFirewall = true.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      enable = lib.mkDefault true;
      allowedTCPPorts = cfg.extraTCPPorts;
      allowedUDPPorts = cfg.extraUDPPorts;
      allowedTCPPortRanges = cfg.extraTCPPortRanges;
      allowedUDPPortRanges = cfg.extraUDPPortRanges;
    };
  };
}
