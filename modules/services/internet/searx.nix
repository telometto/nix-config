{ config, lib, pkgs, myVars, ... }:

{
  services.searx = {
    enable = true;

    redisCreateLocally = true;

    settings = {
      server = {
        secret_key = myVars.server.searxSecretKey;
        port = 7777;
        bind_address = "0.0.0.0";
      };

      search = {
        formats = [ "html" "json" "rss" ];
      };
    };
  };

  environment.systemPackages = with pkgs; [ searxng ];
}
