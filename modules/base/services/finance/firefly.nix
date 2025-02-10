{ config, lib, pkgs, ... }:

{
  services.firefly-iii = {
    enable = true;

    settings = {
      APP_ENV = "local";
      APP_KEY_FILE = "/opt/sec/ff-file";
      enableNginx = true;
      virtualHost = "firefly.blizzard.INTERNAL";
    };
  };
}
