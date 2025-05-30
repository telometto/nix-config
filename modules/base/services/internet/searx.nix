{ config, lib, pkgs, ... }:

{
  services.searx = {
    enable = true;

    redisCreateLocally = true;

    settings = {
      server = {
        secret_key = config.sops.secrets."general/searxSecretKey".path; # config.sops.secrets.searxSecretKey.path;
        port = 7777;
        bind_address = "0.0.0.0"; # Listen on all interfaces
      };

      search = {
        formats = [ "html" "json" "rss" ];
      };
    };
  };

  sops.secrets."general/searxSecretKey" = { };

  environment.systemPackages = with pkgs; [ searxng ];
}
