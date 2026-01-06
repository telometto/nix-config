{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.telometto.services.electricityPriceExporter;

  pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);

  exporterScript = pkgs.stdenv.mkDerivation {
    name = "electricity-price-exporter";
    src = ./scripts/electricity-price-exporter.py;
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/electricity-price-exporter
      chmod +x $out/bin/electricity-price-exporter
    '';
  };
in
{
  options.telometto.services.electricityPriceExporter = {
    enable = lib.mkEnableOption "Norwegian electricity price Prometheus exporter";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9101;
      description = "Port on which the exporter listens";
    };

    priceArea = lib.mkOption {
      type = lib.types.enum [
        "NO1"
        "NO2"
        "NO3"
        "NO4"
        "NO5"
      ];
      default = "NO2";
      description = ''
        Norwegian price area:
        - NO1 = Oslo / Øst-Norge
        - NO2 = Kristiansand / Sør-Norge
        - NO3 = Trondheim / Midt-Norge
        - NO4 = Tromsø / Nord-Norge (no MVA)
        - NO5 = Bergen / Vest-Norge
      '';
    };

    useNorgespris = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to use Norgespris (fixed price scheme) instead of spot prices.

        Norgespris gives a fixed price of 50 øre/kWh (incl. MVA) for electricity,
        valid from October 1, 2025 to December 31, 2026. The scheme has a cap of
        5000 kWh/month for households and 1000 kWh/month for cabins.

        When enabled, the exporter will report both the actual spot price and
        the Norgespris, allowing you to compare costs.

        See: https://www.nve.no/reguleringsmyndigheten/kunde/stroem/dette-er-norgespris/
      '';
    };

    gridOwner = lib.mkOption {
      type = lib.types.str;
      default = "fagne";
      description = ''
        Grid owner (netteier) for grid tariff calculations.

        Currently supports:
        - "fagne" - Fagne AS (default)

        Grid tariff data is based on fri-nettleie:
        https://github.com/kraftsystemet/fri-nettleie

        Fagne AS tariff structure:
        - Base price (off-peak): 20 øre/kWh
        - Peak price (weekdays 06:00-21:00): 28 øre/kWh
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for the exporter port";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.electricity-price-exporter = {
      description = "Norwegian electricity price Prometheus exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        PRICE_AREA = cfg.priceArea;
        LISTEN_PORT = toString cfg.port;
        USE_NORGESPRIS = if cfg.useNorgespris then "true" else "false";
        GRID_OWNER = cfg.gridOwner;
      };

      serviceConfig = {
        ExecStart = "${pythonEnv}/bin/python3 ${exporterScript}/bin/electricity-price-exporter";
        Restart = "always";
        RestartSec = 10;
        DynamicUser = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
