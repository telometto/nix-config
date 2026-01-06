# NUT (Network UPS Tools) module for UPS monitoring
# Supports Eaton 9130 and similar UPS devices
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.telometto.services.ups;

  # Helper to generate UPS configuration
  mkUpsConfig = name: upsCfg: {
    inherit (upsCfg) driver port;
    description = upsCfg.description or "${upsCfg.driver} UPS";
    directives = upsCfg.directives or [ ];
  };
in
{
  options.telometto.services.ups = {
    enable = lib.mkEnableOption "UPS monitoring with NUT";

    mode = lib.mkOption {
      type = lib.types.enum [
        "standalone"
        "netserver"
        "netclient"
      ];
      default = "standalone";
      description = ''
        NUT operation mode:
        - standalone: UPS connected directly, no network sharing
        - netserver: UPS connected directly, shares data over network
        - netclient: Connects to remote NUT server
      '';
    };

    devices = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            driver = lib.mkOption {
              type = lib.types.str;
              default = "usbhid-ups";
              description = ''
                NUT driver for this UPS. Common options:
                - usbhid-ups: Most USB-connected UPS (recommended for Eaton 9130)
                - bcmxcp: Eaton/Powerware serial devices
                - snmp-ups: Network-connected UPS with SNMP card
              '';
            };

            port = lib.mkOption {
              type = lib.types.str;
              default = "auto";
              description = ''
                Port/device path for the UPS:
                - "auto": Auto-detect USB device (recommended for USB)
                - "/dev/ttyS0" or "/dev/ttyUSB0": Serial port
                - IP address: For SNMP-based connections
              '';
            };

            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Human-readable description of this UPS";
            };

            directives = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Additional directives for ups.conf.
                Example: [ "pollinterval = 5" "vendor = Eaton" ]
              '';
              example = [
                "pollinterval = 5"
                "vendor = Eaton"
              ];
            };
          };
        }
      );
      default = { };
      description = "UPS devices to monitor";
      example = {
        eaton9130 = {
          driver = "usbhid-ups";
          port = "auto";
          description = "Eaton 9130 UPS";
        };
      };
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for NUT daemon (port 3493)";
    };

    users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            passwordFile = lib.mkOption {
              type = lib.types.path;
              description = "Path to file containing the password for this NUT user";
            };

            upsmon = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.enum [
                  "primary"
                  "secondary"
                ]
              );
              default = null;
              description = ''
                UPS monitoring role:
                - primary: This machine controls UPS shutdown
                - secondary: This machine only monitors, doesn't control shutdown
              '';
            };

            actions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Allowed actions for this user (SET, FSD)";
              example = [
                "SET"
                "FSD"
              ];
            };

            instcmds = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Allowed instant commands (ALL or specific commands)";
              example = [
                "ALL"
              ];
            };
          };
        }
      );
      default = { };
      description = "NUT users for authentication";
    };

    monitorUser = lib.mkOption {
      type = lib.types.str;
      default = "upsmon";
      description = "NUT user for upsmon to use";
    };

    monitorPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing password for the monitor user";
    };

    prometheusExporter = {
      enable = lib.mkEnableOption "Prometheus NUT exporter";

      port = lib.mkOption {
        type = lib.types.port;
        default = 9199;
        description = "Port for the Prometheus NUT exporter";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall for NUT exporter";
      };

      variables = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          List of NUT variables to export. Empty means all numeric variables.
          See: https://github.com/DRuggeri/nut_exporter
        '';
        example = [
          "battery.charge"
          "battery.runtime"
          "ups.load"
          "ups.power"
          "input.voltage"
          "output.voltage"
        ];
      };
    };

    shutdownOrder = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = ''
        Shutdown order when UPS battery is critical.
        Higher values = shutdown later.
        Useful when multiple machines are on same UPS.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Basic NUT configuration
      {
        power.ups = {
          enable = true;
          inherit (cfg) mode openFirewall;

          ups = lib.mapAttrs mkUpsConfig cfg.devices;

          users = lib.mapAttrs (name: userCfg: {
            inherit (userCfg)
              passwordFile
              upsmon
              actions
              instcmds
              ;
          }) cfg.users;

          upsmon = lib.mkIf (cfg.monitorPasswordFile != null) {
            enable = true;

            monitor = lib.mapAttrs' (
              upsName: _upsCfg:
              lib.nameValuePair "${upsName}@localhost" {
                user = cfg.monitorUser;
                passwordFile = cfg.monitorPasswordFile;
                type = "primary";
                powerValue = 1;
              }
            ) cfg.devices;

            settings = {
              MINSUPPLIES = 1;
              SHUTDOWNCMD = "${pkgs.systemd}/bin/systemctl poweroff";
              POLLFREQ = 5;
              POLLFREQALERT = 5;
              HOSTSYNC = 15;
              DEADTIME = 15;
              RBWARNTIME = 43200; # 12 hours
              NOCOMMWARNTIME = 300; # 5 minutes
              FINALDELAY = 5;
            };
          };
        };

        # Ensure nut package is available
        environment.systemPackages = [ pkgs.nut ];
      }

      # Prometheus NUT exporter
      (lib.mkIf cfg.prometheusExporter.enable {
        services.prometheus.exporters.nut = {
          enable = true;
          inherit (cfg.prometheusExporter)
            port
            openFirewall
            ;
          nutServer = "127.0.0.1";
          nutVariables = cfg.prometheusExporter.variables;
        };
      })
    ]
  );
}
