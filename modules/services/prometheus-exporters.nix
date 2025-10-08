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
        default = [ "systemd" ];
        description = "List of enabled collectors";
        example = [
          "systemd"
          "processes"
        ];
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
    # Auto-enable node exporter if Prometheus is enabled
    {
      telometto.services.prometheusExporters.node.enable = lib.mkDefault (
        config.telometto.services.prometheus.enable or false
      );
    }

    # Configure node exporter
    (lib.mkIf cfg.node.enable {
      services.prometheus.exporters.node = {
        enable = true;
        inherit (cfg.node)
          port
          openFirewall
          enabledCollectors
          extraFlags
          ;
      };
    })

    # Configure ZFS exporter
    (lib.mkIf cfg.zfs.enable {
      services.prometheus.exporters.zfs = {
        enable = true;
        inherit (cfg.zfs) port openFirewall pools;
      };
    })
  ];
}
