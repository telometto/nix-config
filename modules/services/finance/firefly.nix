{ config, lib, pkgs, ... }:

{
  services.firefly-iii = {
    enable = true;

    enableNginx = true;
    # virtualHost = "firefly.example.com";

    settings = {
      APP_ENV = "local";
      APP_KEY_FILE = "/opt/sec/ff-file";
      # APP_URL = "http://localhost:8080";
    };
  };
}
