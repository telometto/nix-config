{ lib, config, ... }:
let
  cfg = config.telometto.services.prometheusExporters;
in
{
  options.telometto.services.prometheusExporters = {
    node = {
      enable = lib.mkEnableOption "Prometheus Node Exporter" // {
        default = config.telometto.services.prometheus.enable or false;
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 9100;
        description = "Port on which the node exporter listens";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall for node exporter port";
      };

      enabledCollectors = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "systemd"
          "zfs"
        ];
        description = "List of enabled collectors";
        example = [
          "systemd"
          "processes"
          "zfs"
          "rapl"
          "hwmon"
        ];
      };

      enableRapl = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable RAPL (Running Average Power Limit) power monitoring.
          This adds the rapl and hwmon collectors and grants the necessary
          capability (CAP_DAC_READ_SEARCH) to read power metrics.
        '';
      };

      extraFlags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--collector.ethtool"
          "--collector.softirqs"
          "--collector.tcpstat"
        ];
        description = "Extra flags to pass to node_exporter";
      };
    };

    zfs = {
      enable = lib.mkEnableOption "Prometheus ZFS Exporter";

      port = lib.mkOption {
        type = lib.types.port;
        default = 9134;
        description = "Port on which the ZFS exporter listens";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall for ZFS exporter port";
      };

      pools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of ZFS pools to monitor. Empty list means all pools.";
        example = [
          "rpool"
          "tank"
        ];
      };
    };
  };

  config = lib.mkMerge [
    {
      telometto.services.prometheusExporters.node.enable = lib.mkDefault (
        config.telometto.services.prometheus.enable or false
      );
    }

    (lib.mkIf cfg.node.enable {
      services.prometheus.exporters.node = {
        enable = lib.mkDefault true;
        inherit (cfg.node)
          port
          openFirewall
          extraFlags
          ;
        enabledCollectors =
          cfg.node.enabledCollectors
          ++ lib.optionals cfg.node.enableRapl [
            "rapl"
            "hwmon"
          ];
      };

      # Grant capability to read RAPL energy files when enableRapl is true
      systemd.services.prometheus-node-exporter = lib.mkIf cfg.node.enableRapl {
        serviceConfig = {
          AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
          CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
        };
      };
    })

    (lib.mkIf cfg.zfs.enable {
      services.prometheus.exporters.zfs = {
        enable = lib.mkDefault true;
        inherit (cfg.zfs) port openFirewall pools;
      };
    })
  ];
}
