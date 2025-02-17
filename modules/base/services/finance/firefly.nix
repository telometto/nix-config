{ config, lib, pkgs, ... }:

{
  services.firefly-iii = {
    enable = true;

    enableNginx = false;
    # virtualHost = "firefly.example.com";

    settings = {
      APP_ENV = "local";
      APP_KEY_FILE = "/opt/sec/ff-file";
      APP_URL = "http://192.168.2.100:4040";
    };
  };
}
