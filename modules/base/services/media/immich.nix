# Not in use yet; just have entered all the options as placeholders
{ config, lib, pkgs, ... }:

{
  services.immich = {
    enable = false;

    host = "192.168.4.100"; # Default: "localhost"
    #port = 2283; # Default: 3001
    #openFirewall = true;

    #user = "immich";
    #group = "immich";

    secretsFile = "/opt/sec/immich-file"; # Default: null
    mediaLocation = "/tank/apps/immich/library"; # Default: "/var/lib/immich"

    environment = {
      IMMICH_LOG_LEVEL = "verbose"; # Example
    };

    database = {
      enable = true; # Default: true

      host = "/tank/apps/immich/postgres"; # Default: "/run/postgresql"
      #port = 5432; # Default: 5432

      #user = "immich"; # Default: "immich"
      #name = "immich"; # Default: "immich"
      #createDB = true; # Default: true
    };

    redis = {
      enable = true;

      #host = "192.168.2.100"; # Default: config.services.redis.servers.immich.unixSocket
      #port = 0; # Default: 0
    };

    machine-learning = {
      enable = true;

      environment = {
        MACHINE_LEARNING_MODEL_TTL = "600"; # Example
      };
    };
  };
}
