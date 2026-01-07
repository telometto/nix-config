{ lib, ... }:
{
  options.sys.role = {
    desktop.enable = lib.mkEnableOption "Desktop role toggle";
    server.enable = lib.mkEnableOption "Server role toggle";
  };
}
