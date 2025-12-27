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
