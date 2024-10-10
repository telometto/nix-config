{ config, lib, pkgs, ... }:

{
  services.immich = {
    host = "192.168.4.100";
  };
}
