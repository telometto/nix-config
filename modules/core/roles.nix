{ lib, config, ... }:
{
  options.sys.role = {
    desktop.enable = lib.mkEnableOption "Desktop role toggle";
    server.enable = lib.mkEnableOption "Server role toggle";
  };

  config.assertions = [
    {
      assertion = !(config.sys.role.desktop.enable && config.sys.role.server.enable);
      message = "sys.role.desktop.enable and sys.role.server.enable are mutually exclusive";
    }
  ];
}
