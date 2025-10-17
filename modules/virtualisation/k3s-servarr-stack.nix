# Servarr Stack Configuration for k3s-apps module
# This file defines the Servarr media automation stack (Radarr, Sonarr, etc.)
{ config, lib, ... }:

{
  telometto.services."k3s-servarr" = {
    enable = true;

    # Namespace for all servarr apps
    namespace = "servarr";
    storageClass = "servarr-sc";

    # Shared downloads storage for all *arr apps
    sharedStorage = {
      pvName = "arr-downloads";
      pvcName = "arr-pvc-downloads";
      path = "/rpool/unenc/media/data";
      size = "10Ti";
      mountPath = "/data";
    };

    apps = {
      radarr = {
        enable = true;
        image = "linuxserver/radarr:latest";
        port = 7878;

        env = {
          PUID = "1000";
          PGID = "1000";
          TZ = "Europe/Oslo";
          RADARR__URLBASE = "/radarr";
        };

        storage = {
          path = "/rpool/unenc/apps/kubernetes/servarr/radarr/config";
          size = "1Gi";
          mountPath = "/config";
        };
        useSharedStorage = true;  # Mount the shared downloads volume
      };

      sonarr = {
        enable = true;
        image = "linuxserver/sonarr:latest";
        port = 8989;

        env = {
          PUID = "1000";
          PGID = "1000";
          TZ = "Europe/Oslo";
          SONARR__URLBASE = "/sonarr";
        };

        storage = {
          path = "/rpool/unenc/apps/kubernetes/servarr/sonarr/config";
          size = "1Gi";
          mountPath = "/config";
        };

        useSharedStorage = true;
      };

      lidarr = {
        enable = true;
        image = "linuxserver/lidarr:latest";
        port = 8686;

        env = {
          PUID = "1000";
          PGID = "1000";
          TZ = "Europe/Oslo";
          LIDARR__URLBASE = "/lidarr";
        };

        storage = {
          path = "/rpool/unenc/apps/kubernetes/servarr/lidarr/config";
          size = "1Gi";
          mountPath = "/config";
        };

        useSharedStorage = true;
      };

      readarr = {
        enable = true;
        image = "linuxserver/readarr:develop";  # readarr uses develop tag
        port = 8787;

        env = {
          PUID = "1000";
          PGID = "1000";
          TZ = "Europe/Oslo";
          READARR__URLBASE = "/readarr";
        };

        storage = {
          path = "/rpool/unenc/apps/kubernetes/servarr/readarr/config";
          size = "1Gi";
          mountPath = "/config";
        };
        useSharedStorage = true;
      };

      prowlarr = {
        enable = true;
        image = "linuxserver/prowlarr:latest";
        port = 9696;

        env = {
          PUID = "1000";
          PGID = "1000";
          TZ = "Europe/Oslo";
          PROWLARR__URLBASE = "/prowlarr";
        };

        storage = {
          path = "/rpool/unenc/apps/kubernetes/servarr/prowlarr/config";
          size = "1Gi";
          mountPath = "/config";
        };

        useSharedStorage = false;  # Prowlarr doesn't need downloads
      };

      bazarr = {
        enable = true;
        image = "linuxserver/bazarr:latest";
        port = 6767;

        env = {
          PUID = "1000";
          PGID = "1000";
          TZ = "Europe/Oslo";
          BAZARR__URLBASE = "/bazarr";
        };

        storage = {
          path = "/rpool/unenc/apps/kubernetes/servarr/bazarr/config";
          size = "1Gi";
          mountPath = "/config";
        };

        useSharedStorage = true;
      };

      flaresolverr = {
        enable = true;
        image = "ghcr.io/flaresolverr/flaresolverr:latest";
        port = 8191;
        
        env = {
          LOG_LEVEL = "info";
          TZ = "Europe/Oslo";
        };

        # Flaresolverr doesn't need persistent storage
        storage = null;
        useSharedStorage = false;
        service.type = "ClusterIP";  # Internal only
      };
    };
  };

  # Traefik reverse proxy configuration for Servarr apps
  # This integrates with the host's Traefik service
  telometto.services.traefik.services = lib.mkIf (config.telometto.services."k3s-servarr".enable or false) {
    radarr = {
      backendUrl = "http://192.168.2.100:7878/";
      pathPrefix = "/radarr";
      stripPrefix = false;
      customHeaders = {
        X-Forwarded-Proto = "https";
        X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
      };
    };

    sonarr = {
      backendUrl = "http://192.168.2.100:8989/";
      pathPrefix = "/sonarr";
      stripPrefix = false;
      customHeaders = {
        X-Forwarded-Proto = "https";
        X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
      };
    };

    lidarr = {
      backendUrl = "http://192.168.2.100:8686/";
      pathPrefix = "/lidarr";
      stripPrefix = false;
      customHeaders = {
        X-Forwarded-Proto = "https";
        X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
      };
    };

    readarr = {
      backendUrl = "http://192.168.2.100:8787/";
      pathPrefix = "/readarr";
      stripPrefix = false;
      customHeaders = {
        X-Forwarded-Proto = "https";
        X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
      };
    };

    prowlarr = {
      backendUrl = "http://192.168.2.100:9696/";
      pathPrefix = "/prowlarr";
      stripPrefix = false;
      customHeaders = {
        X-Forwarded-Proto = "https";
        X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
      };
    };

    bazarr = {
      backendUrl = "http://192.168.2.100:6767/";
      pathPrefix = "/bazarr";
      stripPrefix = false;
      customHeaders = {
        X-Forwarded-Proto = "https";
        X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
      };
    };
  };
}
