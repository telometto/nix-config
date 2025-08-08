# Utility functions for the configuration
{ lib, VARS }:

rec {
  # Device type detection
  deviceTypes = {
    desktop = VARS.systems.desktop.hostName;
    laptop = VARS.systems.laptop.hostName;
    server = VARS.systems.server.hostName;
  };

  # Check if current host is of specific type
  isDesktop = hostName: hostName == deviceTypes.desktop;
  isLaptop = hostName: hostName == deviceTypes.laptop;
  isServer = hostName: hostName == deviceTypes.server;

  # Common module builder
  mkModule = { condition ? true, config }: lib.mkIf condition config;

  # Host-specific module builder
  mkHostModule = hostName: config:
    mkModule {
      condition = (hostName == deviceTypes.desktop)
        || (hostName == deviceTypes.laptop) || (hostName == deviceTypes.server);
      inherit config;
    };

  # Device type conditional config
  mkDesktopConfig = hostName: config:
    mkModule {
      condition = isDesktop hostName;
      inherit config;
    };
  mkLaptopConfig = hostName: config:
    mkModule {
      condition = isLaptop hostName;
      inherit config;
    };
  mkServerConfig = hostName: config:
    mkModule {
      condition = isServer hostName;
      inherit config;
    };
}
