{ config, lib, pkgs, ... }:

{
  services.searx = {
    enable = true;

    redisCreateLocally = true;
    
    settings = {
      server = {
        secret_key = "test";
        port = 7777;
        bind_address = "192.168.4.100";
      };

      search = {
        formats = [ "html" "json" "rss" ];
      };
    };
  };
}