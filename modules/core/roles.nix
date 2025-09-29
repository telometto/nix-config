# What is this/where is this imported/what does it do?
{ lib, ... }:
{
  options.telometto.role = {
    desktop.enable = lib.mkEnableOption "Desktop role toggle";
    server.enable = lib.mkEnableOption "Server role toggle";
  };
}
