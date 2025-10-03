{ lib, config, ... }:
let
  cfg = config.telometto.networking.firewall;
  portRangeType = lib.types.submodule (_: {
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
in
{
  options.telometto.networking.firewall = {
    enable = lib.mkEnableOption "Firewall base policy";
    
    # Global ports (exposed on ALL interfaces - use sparingly!)
    extraTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Individual TCP ports to allow on ALL interfaces (exposed to internet).";
    };
    extraUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Individual UDP ports to allow on ALL interfaces (exposed to internet).";
    };
    extraTCPPortRanges = lib.mkOption {
      type = lib.types.listOf portRangeType;
      default = [ ];
      description = "TCP port ranges to allow on ALL interfaces (exposed to internet).";
    };
    extraUDPPortRanges = lib.mkOption {
      type = lib.types.listOf portRangeType;
      default = [ ];
      description = "UDP port ranges to allow on ALL interfaces (exposed to internet).";
    };

    # LAN-specific ports (only accessible from local network)
    lan = {
      interface = lib.mkOption {
        type = lib.types.str;
        default = "enp8s0";  # Your physical LAN interface
        description = "Network interface connected to your LAN.";
      };
      allowedTCPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
        description = "TCP ports to allow only on LAN interface (local network only).";
      };
      allowedUDPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
        description = "UDP ports to allow only on LAN interface (local network only).";
      };
      allowedTCPPortRanges = lib.mkOption {
        type = lib.types.listOf portRangeType;
        default = [ ];
        description = "TCP port ranges to allow only on LAN interface (local network only).";
      };
      allowedUDPPortRanges = lib.mkOption {
        type = lib.types.listOf portRangeType;
        default = [ ];
        description = "UDP port ranges to allow only on LAN interface (local network only).";
      };
    };

    # Tailscale-specific ports (only accessible via Tailscale VPN)
    tailscale = {
      allowedTCPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
        description = "TCP ports to allow only on Tailscale interface (private).";
      };
      allowedUDPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
        description = "UDP ports to allow only on Tailscale interface (private).";
      };
      allowedTCPPortRanges = lib.mkOption {
        type = lib.types.listOf portRangeType;
        default = [ ];
        description = "TCP port ranges to allow only on Tailscale interface (private).";
      };
      allowedUDPPortRanges = lib.mkOption {
        type = lib.types.listOf portRangeType;
        default = [ ];
        description = "UDP port ranges to allow only on Tailscale interface (private).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      enable = lib.mkDefault true;
      
      # Global rules (ALL interfaces)
      allowedTCPPorts = cfg.extraTCPPorts;
      allowedUDPPorts = cfg.extraUDPPorts;
      allowedTCPPortRanges = cfg.extraTCPPortRanges;
      allowedUDPPortRanges = cfg.extraUDPPortRanges;

      # Interface-specific rules
      interfaces = {
        # Tailscale interface
        "tailscale0" = {
          allowedTCPPorts = cfg.tailscale.allowedTCPPorts;
          allowedUDPPorts = cfg.tailscale.allowedUDPPorts;
          allowedTCPPortRanges = cfg.tailscale.allowedTCPPortRanges;
          allowedUDPPortRanges = cfg.tailscale.allowedUDPPortRanges;
        };
        
        # LAN interface (typically eth0, enp8s0, etc.)
        "${cfg.lan.interface}" = {
          allowedTCPPorts = cfg.lan.allowedTCPPorts;
          allowedUDPPorts = cfg.lan.allowedUDPPorts;
          allowedTCPPortRanges = cfg.lan.allowedTCPPortRanges;
          allowedUDPPortRanges = cfg.lan.allowedUDPPortRanges;
        };
      };
    };
  };
}
