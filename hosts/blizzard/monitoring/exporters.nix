{ config, consts, ... }:
{
  sys.services = {
    prometheusExporters = {
      node = {
        enableRapl = true;
        port = consts.ports.host.nodeExporter;
      };

      zfs = {
        enable = true;

        port = consts.ports.host.zfsExporter;
      };
    };

    electricityPriceExporter = {
      enable = true;

      port = consts.ports.host.electricityPriceExporter;
      priceArea = "NO2";
    };

    cloudflareMetrics = {
      enable = true;

      port = consts.ports.host.cloudflareMetrics;
      apiTokenFile = config.sys.secrets.cloudflareMetricsApiTokenFile;
      accountIdFile = config.sys.secrets.cloudflareAccountIdFile;
      ownerEmailsFile = config.sys.secrets.cloudflareAccessOwnerEmailsFile;
    };

    # UPS monitoring (Eaton 9130)
    ups = {
      enable = true;

      mode = "standalone";

      devices.eaton9130 = {
        driver = "usbhid-ups";
        port = "auto";
        description = "Eaton 9130 UPS";
        directives = [
          "pollinterval = 5"
          "lowbatt = 30"
        ];
      };

      users.upsmon = {
        passwordFile = config.sys.secrets.upsmonPasswordFile;
        upsmon = "primary";

        actions = [
          "SET"
          "FSD"
        ];

        instcmds = [ "ALL" ];
      };

      monitorUser = "upsmon";
      monitorPasswordFile = config.sys.secrets.upsmonPasswordFile;
      shutdownOrder = 0;

      prometheusExporter = {
        enable = true;

      port = consts.ports.host.upsExporter;
        variables = [
          "battery.charge"
          "battery.charge.low"
          "battery.runtime"
          "input.frequency"
          "input.voltage"
          "input.voltage.nominal"
          "outlet.1.status"
          "outlet.2.status"
          "outlet.1.switchable"
          "outlet.2.switchable"
          "outlet.1.delay.shutdown"
          "outlet.2.delay.shutdown"
          "output.current"
          "output.frequency"
          "output.voltage"
          "output.voltage.nominal"
          "ups.load"
          "ups.power"
          "ups.realpower"
          "ups.status"
          "ups.temperature"
        ];
      };
    };
  };
}
