# Download Management Stack with WireGuard VPN
# Multi-container pod deployment (requires manual manifest - see below)
{ config, lib, ... }:

let
  # Access SOPS secrets for Firefox via the telometto.secrets convenience layer
  ffUser = config.telometto.secrets.firefoxUser;
  ffPassword = config.telometto.secrets.firefoxPassword;
in
{
  # Note: The original setup uses a single pod with multiple containers (sidecar pattern)
  # This is NOT directly supported by the generic k3s-apps module
  # We provide a complete manual manifest below

  services.k3s.manifests = lib.mkIf (config.telometto.services."k3s-download-mgmt".enable or false) {
    # Namespace
    "download-mgmt-namespace" = {
      apiVersion = "v1";
      kind = "Namespace";
      metadata.name = "download-management";
    };

    # Storage Class
    "download-mgmt-sc" = {
      apiVersion = "storage.k8s.io/v1";
      kind = "StorageClass";
      metadata.name = "download-management-sc";
      provisioner = "kubernetes.io/no-provisioner";
      volumeBindingMode = "WaitForFirstConsumer";
      reclaimPolicy = "Retain";
      allowVolumeExpansion = true;
    };

    # WireGuard Config PV/PVC
    "wg-pv" = {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata.name = "wg-pv-config";
      spec = {
        storageClassName = "download-management-sc";
        capacity.storage = "1Gi";
        accessModes = [ "ReadWriteOnce" ];
        persistentVolumeReclaimPolicy = "Retain";
        hostPath.path = "/rpool/unenc/apps/kubernetes/servarr/wireguard/config";
      };
    };

    "wg-pvc" = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "wg-pvc-config";
        namespace = "download-management";
      };
      spec = {
        storageClassName = "download-management-sc";
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "1Gi";
        volumeName = "wg-pv-config";
      };
    };

    # qBittorrent Config PV/PVC
    "qb-config-pv" = {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata.name = "qb-pv-config";
      spec = {
        storageClassName = "download-management-sc";
        capacity.storage = "1Gi";
        accessModes = [ "ReadWriteOnce" ];
        persistentVolumeReclaimPolicy = "Retain";
        hostPath.path = "/rpool/unenc/apps/kubernetes/servarr/qbittorrent/config";
      };
    };

    "qb-config-pvc" = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "qb-pvc-config";
        namespace = "download-management";
      };
      spec = {
        storageClassName = "download-management-sc";
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "1Gi";
        volumeName = "qb-pv-config";
      };
    };

    # qBittorrent Downloads PV/PVC
    "qb-downloads-pv" = {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata.name = "qb-pv-downloads";
      spec = {
        storageClassName = "download-management-sc";
        capacity.storage = "5Ti";
        accessModes = [ "ReadWriteOnce" ];
        persistentVolumeReclaimPolicy = "Retain";
        hostPath.path = "/rpool/unenc/media/data/torrents";
      };
    };

    "qb-downloads-pvc" = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "qb-pvc-downloads";
        namespace = "download-management";
      };
      spec = {
        storageClassName = "download-management-sc";
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Ti";
        volumeName = "qb-pv-downloads";
      };
    };

    # SABnzbd Config PV/PVC
    "sabnzbd-config-pv" = {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata.name = "sabnzbd-pv-config";
      spec = {
        storageClassName = "download-management-sc";
        capacity.storage = "1Gi";
        accessModes = [ "ReadWriteOnce" ];
        persistentVolumeReclaimPolicy = "Retain";
        hostPath.path = "/rpool/unenc/apps/kubernetes/servarr/sabnzbd/config";
      };
    };

    "sabnzbd-config-pvc" = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "sabnzbd-pvc-config";
        namespace = "download-management";
      };
      spec = {
        storageClassName = "download-management-sc";
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "1Gi";
        volumeName = "sabnzbd-pv-config";
      };
    };

    # SABnzbd Downloads PV/PVC
    "sabnzbd-downloads-pv" = {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata.name = "sabnzbd-pv-downloads";
      spec = {
        storageClassName = "download-management-sc";
        capacity.storage = "5Ti";
        accessModes = [ "ReadWriteOnce" ];
        persistentVolumeReclaimPolicy = "Retain";
        hostPath.path = "/rpool/unenc/media/data/usenet";
      };
    };

    "sabnzbd-downloads-pvc" = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "sabnzbd-pvc-downloads";
        namespace = "download-management";
      };
      spec = {
        storageClassName = "download-management-sc";
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Ti";
        volumeName = "sabnzbd-pv-downloads";
      };
    };

    # Firefox Config PV/PVC
    "ff-config-pv" = {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata.name = "ff-pv-config";
      spec = {
        storageClassName = "download-management-sc";
        capacity.storage = "1Gi";
        accessModes = [ "ReadWriteOnce" ];
        persistentVolumeReclaimPolicy = "Retain";
        hostPath.path = "/rpool/unenc/apps/kubernetes/servarr/firefox/config";
      };
    };

    "ff-config-pvc" = {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "ff-pvc-config";
        namespace = "download-management";
      };
      spec = {
        storageClassName = "download-management-sc";
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "1Gi";
        volumeName = "ff-pv-config";
      };
    };

    # ConfigMaps
    "wg-configmap" = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "wg-configmap";
        namespace = "download-management";
      };
      data = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Europe/Oslo";
        ALLOWEDIPS = "0.0.0.0/0";
        LOG_CONFS = "true";
      };
    };

    "qb-configmap" = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "qb-configmap";
        namespace = "download-management";
      };
      data = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Europe/Oslo";
        WEBUI_PORT = "8090";
        TORRENTING_PORT = "50820";
      };
    };

    "sabnzbd-configmap" = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "sabnzbd-configmap";
        namespace = "download-management";
      };
      data = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Europe/Oslo";
      };
    };

    "ff-configmap" = {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "ff-configmap";
        namespace = "download-management";
      };
      data = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Europe/Oslo";
        DRINODE = "/dev/dri/renderD128";
        CUSTOM_USER = ffUser;
        PASSWORD = ffPassword;
        TITLE = "Firefox";
      };
    };

    # Multi-container Deployment (WireGuard + download clients)
    "download-mgmt-deployment" = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "download-management";
        namespace = "download-management";
      };
      spec = {
        replicas = 1;
        selector.matchLabels.app = "download-management";
        strategy = {
          type = "RollingUpdate";
          rollingUpdate = {
            maxSurge = 0;
            maxUnavailable = 1;
          };
        };
        template = {
          metadata.labels.app = "download-management";
          spec = {
            restartPolicy = "Always";
            containers = [
              # WireGuard VPN container
              {
                name = "wireguard";
                image = "linuxserver/wireguard:latest";
                envFrom = [ { configMapRef.name = "wg-configmap"; } ];
                volumeMounts = [
                  {
                    name = "wg-config";
                    mountPath = "/config";
                  }
                  {
                    name = "lib-modules";
                    mountPath = "/lib/modules";
                    readOnly = true;
                  }
                ];
                readinessProbe = {
                  exec.command = [
                    "/bin/sh"
                    "-c"
                    "wg show"
                  ];
                  initialDelaySeconds = 15;
                  periodSeconds = 15;
                };
                livenessProbe = {
                  exec.command = [
                    "/bin/sh"
                    "-c"
                    "wg show"
                  ];
                  initialDelaySeconds = 20;
                  periodSeconds = 25;
                };
                securityContext = {
                  privileged = true;
                  capabilities.add = [
                    "NET_ADMIN"
                    "SYS_MODULE"
                  ];
                };
              }
              # SABnzbd container
              {
                name = "sabnzbd";
                image = "linuxserver/sabnzbd:latest";
                envFrom = [ { configMapRef.name = "sabnzbd-configmap"; } ];
                ports = [
                  {
                    name = "sabnzbd-webui";
                    containerPort = 8080;
                    protocol = "TCP";
                  }
                ];
                volumeMounts = [
                  {
                    name = "sabnzbd-config";
                    mountPath = "/config";
                  }
                  {
                    name = "sabnzbd-downloads";
                    mountPath = "/data/usenet";
                  }
                ];
                securityContext = {
                  runAsNonRoot = false;
                  readOnlyRootFilesystem = false;
                  allowPrivilegeEscalation = false;
                };
              }
              # qBittorrent container
              {
                name = "qbittorrent";
                image = "linuxserver/qbittorrent:latest";
                envFrom = [ { configMapRef.name = "qb-configmap"; } ];
                ports = [
                  {
                    name = "qb-webui";
                    containerPort = 8090;
                    protocol = "TCP";
                  }
                  {
                    name = "qb-tcp";
                    containerPort = 50820;
                    protocol = "TCP";
                  }
                  {
                    name = "qb-udp";
                    containerPort = 50820;
                    protocol = "UDP";
                  }
                ];
                volumeMounts = [
                  {
                    name = "qb-config";
                    mountPath = "/config";
                  }
                  {
                    name = "qb-downloads";
                    mountPath = "/data/torrents";
                  }
                ];
                securityContext = {
                  runAsNonRoot = false;
                  readOnlyRootFilesystem = false;
                  allowPrivilegeEscalation = false;
                };
              }
              # Firefox container
              {
                name = "firefox";
                image = "linuxserver/firefox:latest";
                envFrom = [ { configMapRef.name = "ff-configmap"; } ];
                ports = [
                  {
                    name = "ff-https-webui";
                    containerPort = 3000;
                  }
                ];
                volumeMounts = [
                  {
                    name = "ff-config";
                    mountPath = "/config";
                  }
                  {
                    name = "dshm";
                    mountPath = "/dev/shm";
                  }
                  {
                    name = "devices";
                    mountPath = "/dev/dri";
                    readOnly = true;
                  }
                ];
                securityContext.privileged = true;
              }
            ];
            volumes = [
              {
                name = "wg-config";
                persistentVolumeClaim.claimName = "wg-pvc-config";
              }
              {
                name = "lib-modules";
                hostPath = {
                  path = "/run/current-system/kernel-modules/lib/modules";
                  type = "Directory";
                };
              }
              {
                name = "sabnzbd-config";
                persistentVolumeClaim.claimName = "sabnzbd-pvc-config";
              }
              {
                name = "sabnzbd-downloads";
                persistentVolumeClaim.claimName = "sabnzbd-pvc-downloads";
              }
              {
                name = "qb-config";
                persistentVolumeClaim.claimName = "qb-pvc-config";
              }
              {
                name = "qb-downloads";
                persistentVolumeClaim.claimName = "qb-pvc-downloads";
              }
              {
                name = "ff-config";
                persistentVolumeClaim.claimName = "ff-pvc-config";
              }
              {
                name = "dshm";
                emptyDir = {
                  medium = "Memory";
                  sizeLimit = "2Gi";
                };
              }
              {
                name = "devices";
                hostPath = {
                  path = "/dev/dri";
                  type = "Directory";
                };
              }
            ];
          };
        };
      };
    };

    # Services
    "qb-service" = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "qb-service";
        namespace = "download-management";
      };
      spec = {
        selector.app = "download-management";
        ipFamilyPolicy = "SingleStack";
        ports = [
          {
            name = "qb-webui";
            port = 8090;
            targetPort = 8090;
            protocol = "TCP";
          }
          {
            name = "qb-tcp";
            port = 50820;
            targetPort = 50820;
            protocol = "TCP";
          }
          {
            name = "qb-udp";
            port = 50820;
            targetPort = 50820;
            protocol = "UDP";
          }
        ];
        type = "LoadBalancer";
        # loadBalancerIP = "192.168.7.31";  # Uncomment for static IP
      };
    };

    "sabnzbd-service" = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "sabnzbd-service";
        namespace = "download-management";
      };
      spec = {
        selector.app = "download-management";
        ipFamilyPolicy = "SingleStack";
        ports = [
          {
            name = "sabnzbd-webui";
            port = 8080;
            targetPort = 8080;
            protocol = "TCP";
          }
        ];
        type = "LoadBalancer";
        # loadBalancerIP = "192.168.7.32";  # Uncomment for static IP
      };
    };

    "ff-service" = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "ff-service";
        namespace = "download-management";
      };
      spec = {
        selector.app = "download-management";
        ipFamilyPolicy = "SingleStack";
        ports = [
          {
            name = "ff-https-webui";
            port = 5859;
            targetPort = 3000;
            protocol = "TCP";
          }
        ];
        type = "LoadBalancer";
        # loadBalancerIP = "192.168.7.33";  # Uncomment for static IP
      };
    };
  };

  # Traefik reverse proxy configuration for Firefox
  # This integrates with the host's Traefik service
  telometto.services.traefik.services =
    lib.mkIf (config.telometto.services."k3s-download-mgmt".enable or false)
      {
        firefox = {
          backendUrl = "http://192.168.2.100:3001/";
          pathPrefix = "/firefox";
          stripPrefix = true;
          customHeaders = {
            X-Forwarded-Proto = "https";
            X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
          };
        };

        qbit = {
          backendUrl = "http://192.168.2.100:8090/";
          pathPrefix = "/qbit";
          stripPrefix = true;
          customHeaders = {
            X-Forwarded-Proto = "https";
            X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
            X-Forwarded-Prefix = "/qbit";
          };
        };

        sabnzbd = {
          backendUrl = "http://192.168.2.100:8080/";
          pathPrefix = "/sabnzbd";
          stripPrefix = false;
          customHeaders = {
            X-Forwarded-Proto = "https";
            X-Forwarded-Host = "${config.networking.hostName}.mole-delta.ts.net";
          };
        };
      };

  # Enable option
  options.telometto.services."k3s-download-mgmt" = {
    enable = lib.mkEnableOption "Download Management stack with WireGuard VPN";
  };
}
