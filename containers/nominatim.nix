# Nominatim OpenStreetMap geocoding API container
# Home Manager module - runs rootless via quadlet-nix
{ lib, config, ... }:
let
  cfg = config.services.nominatim-container;
  inherit (config.virtualisation.quadlet) volumes;
in
{
  options.services.nominatim-container = {
    enable = lib.mkEnableOption "Nominatim OpenStreetMap geocoding container";

    port = lib.mkOption {
      type = lib.types.port;
      default = 11080;
      description = "Host port to expose the Nominatim API on.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "mediagis/nominatim:5.3";
      description = "Container image to use.";
    };

    pbfUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://download.geofabrik.de/europe/norway-latest.osm.pbf";
      description = "URL of the OpenStreetMap PBF file to import on first run.";
    };

    replicationUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "https://download.geofabrik.de/europe/norway-updates/";
      description = "Replication base URL for incremental OSM updates. Set null to disable.";
    };

    threads = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of CPU threads for the initial PBF import.";
    };

    shmSize = lib.mkOption {
      type = lib.types.str;
      default = "1g";
      description = "Shared memory size for Postgres inside the container.";
    };

    extraEnvironments = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for the Nominatim container.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.quadlet.volumes.nominatim-data = { };

    virtualisation.quadlet.containers.nominatim = {
      autoStart = true;
      containerConfig = {
        image = cfg.image;
        publishPorts = [ "${toString cfg.port}:8080" ];
        volumes = [ "${volumes.nominatim-data.ref}:/var/lib/postgresql/14/main" ];
        environments = {
          PBF_URL = cfg.pbfUrl;
          THREADS = toString cfg.threads;
        }
        // lib.optionalAttrs (cfg.replicationUrl != null) {
          REPLICATION_URL = cfg.replicationUrl;
          FREEZE = "false";
        }
        // cfg.extraEnvironments;
        shmSize = cfg.shmSize;
        userns = "keep-id";
      };
      serviceConfig = {
        Restart = "on-failure";
        TimeoutStartSec = "infinity";
      };
    };
  };
}
