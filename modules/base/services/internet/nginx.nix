{ config, lib, pkgs, ... }:

{
  services.nginx = {
    enable = true;

    virtualHosts = {
      "firefly.blizzard.INTERNAL" = {
        enableACME = true;
        forceSSL = false;
        root = "/var/www/firefly";
      };
    };
  };
}
