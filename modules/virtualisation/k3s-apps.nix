# ON HOLD
{ ... }:
{ }
/*
  { lib, config, ... }:
  let
    # Type definition for a k3s app stack
    stackType = lib.types.submodule (
      { name, config, ... }:
      {
        options = {
          enable = lib.mkEnableOption "this k3s app stack";

          namespace = lib.mkOption {
            type = lib.types.str;
            default = name;
            description = "Kubernetes namespace for this stack";
          };

          storageClass = lib.mkOption {
            type = lib.types.str;
            default = "${name}-sc";
            description = "Storage class name for this stack";
          };

          sharedStorage = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  pvName = lib.mkOption {
                    type = lib.types.str;
                    description = "PersistentVolume name";
                  };

                  pvcName = lib.mkOption {
                    type = lib.types.str;
                    description = "PersistentVolumeClaim name";
                  };

                  path = lib.mkOption {
                    type = lib.types.str;
                    description = "Host path for storage";
                  };

                  size = lib.mkOption {
                    type = lib.types.str;
                    description = "Storage size";
                  };

                  mountPath = lib.mkOption {
                    type = lib.types.str;
                    default = "/data";
                    description = "Mount path inside containers";
                  };
                };
              }
            );
            default = null;
            description = "Optional shared storage configuration for apps in this stack";
          };

          apps = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  enable = lib.mkEnableOption "this app";

                  image = lib.mkOption {
                    type = lib.types.str;
                    description = "Container image";
                  };

                  port = lib.mkOption {
                    type = lib.types.port;
                    description = "Primary container port";
                  };

                  ports = lib.mkOption {
                    type = lib.types.listOf (
                      lib.types.submodule {
                        options = {
                          name = lib.mkOption {
                            type = lib.types.str;
                            description = "Port name";
                          };

                          containerPort = lib.mkOption {
                            type = lib.types.port;
                            description = "Container port number";
                          };

                          protocol = lib.mkOption {
                            type = lib.types.enum [
                              "TCP"
                              "UDP"
                            ];
                            default = "TCP";
                            description = "Port protocol";
                          };
                        };
                      }
                    );
                    default = [ ];
                    description = "Additional container ports (beyond the primary port)";
                  };

                  env = lib.mkOption {
                    type = lib.types.attrsOf lib.types.str;
                    default = { };
                    description = "Environment variables";
                  };

                  resources = lib.mkOption {
                    type = lib.types.submodule {
                      options = {
                        requests = {
                          cpu = lib.mkOption {
                            type = lib.types.str;
                            default = "250m";
                          };

                          memory = lib.mkOption {
                            type = lib.types.str;
                            default = "64Mi";
                          };
                        };
                        limits = {
                          cpu = lib.mkOption {
                            type = lib.types.str;
                            default = "2000m";
                          };

                          memory = lib.mkOption {
                            type = lib.types.str;
                            default = "4Gi";
                          };
                        };
                      };
                    };
                    default = { };
                    description = "Resource requests and limits";
                  };

                  storage = lib.mkOption {
                    type = lib.types.nullOr (
                      lib.types.submodule {
                        options = {
                          path = lib.mkOption {
                            type = lib.types.str;
                            description = "Host path for storage";
                          };

                          size = lib.mkOption {
                            type = lib.types.str;
                            default = "1Gi";
                            description = "Storage size";
                          };

                          mountPath = lib.mkOption {
                            type = lib.types.str;
                            default = "/config";
                            description = "Mount path inside container";
                          };
                        };
                      }
                    );
                    default = null;
                    description = "Per-app persistent storage";
                  };

                  useSharedStorage = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Whether to mount the stack's shared storage";
                  };

                  service = lib.mkOption {
                    type = lib.types.submodule {
                      options = {
                        type = lib.mkOption {
                          type = lib.types.enum [
                            "ClusterIP"
                            "NodePort"
                            "LoadBalancer"
                          ];
                          default = "LoadBalancer";
                          description = "Kubernetes service type";
                        };

                        loadBalancerIP = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Static IP for LoadBalancer";
                        };
                      };
                    };
                    default = { };
                    description = "Service configuration";
                  };

                  extraVolumeMounts = lib.mkOption {
                    type = lib.types.listOf lib.types.attrs;
                    default = [ ];
                    description = "Additional volume mounts";
                  };

                  extraVolumes = lib.mkOption {
                    type = lib.types.listOf lib.types.attrs;
                    default = [ ];
                    description = "Additional volumes";
                  };

                  emptyDirVolumes = lib.mkOption {
                    type = lib.types.listOf (
                      lib.types.submodule {
                        options = {
                          name = lib.mkOption {
                            type = lib.types.str;
                            description = "Volume name";
                          };

                          mountPath = lib.mkOption {
                            type = lib.types.str;
                            description = "Container mount path";
                          };

                          medium = lib.mkOption {
                            type = lib.types.nullOr (lib.types.enum [ "Memory" ]);
                            default = null;
                            description = "Storage medium (null for disk, 'Memory' for tmpfs)";
                          };

                          sizeLimit = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = "Size limit (e.g., '2Gi')";
                          };
                        };
                      }
                    );
                    default = [ ];
                    description = "EmptyDir volumes for temporary storage";
                  };

                  hostPathVolumes = lib.mkOption {
                    type = lib.types.listOf (
                      lib.types.submodule {
                        options = {
                          name = lib.mkOption {
                            type = lib.types.str;
                            description = "Volume name";
                          };

                          mountPath = lib.mkOption {
                            type = lib.types.str;
                            description = "Container mount path";
                          };

                          hostPath = lib.mkOption {
                            type = lib.types.str;
                            description = "Host path to mount";
                          };

                          type = lib.mkOption {
                            type = lib.types.nullOr (
                              lib.types.enum [
                                "Directory"
                                "File"
                                "DirectoryOrCreate"
                                "FileOrCreate"
                              ]
                            );
                            default = null;
                            description = "Host path type";
                          };

                          readOnly = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                            description = "Mount as read-only";
                          };
                        };
                      }
                    );
                    default = [ ];
                    description = "HostPath volumes for mounting host directories";
                  };
                };
              }
            );
            default = { };
            description = "Apps in this stack";
          };
        };
      }
    );

    # Helper functions to generate manifests
    mkConfigMap = namespace: name: envVars: {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = "${name}-configmap";
        inherit namespace;
      };
      data = envVars;
    };

    mkPersistentVolume = storageClass: name: path: size: {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata.name = "${name}-pv";
      spec = {
        inherit storageClass;
        capacity.storage = size;
        accessModes = [ "ReadWriteOnce" ];
        persistentVolumeReclaimPolicy = "Retain";
        hostPath.path = path;
      };
    };

    mkPersistentVolumeClaim = namespace: storageClass: name: size: {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "${name}-pvc";
        inherit namespace;
      };
      spec = {
        inherit storageClass;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = size;
        volumeName = "${name}-pv";
      };
    };

    mkDeployment = namespace: appName: appCfg: {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = appName;
        inherit namespace;
      };
      spec = {
        replicas = 1;
        selector.matchLabels.app = appName;
        strategy = {
          type = "RollingUpdate";
          rollingUpdate = {
            maxSurge = 0;
            maxUnavailable = 1;
          };
        };
        template = {
          metadata.labels.app = appName;
          spec = {
            restartPolicy = "Always";
            containers = [
              {
                name = appName;
                image = appCfg.image;
                resources = {
                  requests = {
                    cpu = appCfg.resources.requests.cpu;
                    memory = appCfg.resources.requests.memory;
                  };

                  limits = {
                    cpu = appCfg.resources.limits.cpu;
                    memory = appCfg.resources.limits.memory;
                  };
                };

                envFrom = lib.optional (appCfg.env != { }) {
                  configMapRef.name = "${appName}-configmap";
                };

                ports = [
                  {
                    name = "http";
                    containerPort = appCfg.port;
                    protocol = "TCP";
                  }
                ]
                ++ appCfg.ports;

                volumeMounts =
                  lib.optional (appCfg.storage != null) {
                    name = "${appName}-storage";
                    mountPath = appCfg.storage.mountPath;
                  }
                  ++ (map (vol: {
                    name = vol.name;
                    mountPath = vol.mountPath;
                  }) appCfg.emptyDirVolumes)
                  ++ (map (vol: {
                    name = vol.name;
                    mountPath = vol.mountPath;
                    readOnly = vol.readOnly;
                  }) appCfg.hostPathVolumes)
                  ++ appCfg.extraVolumeMounts;
              }
            ];

            volumes =
              lib.optional (appCfg.storage != null) {
                name = "${appName}-storage";
                persistentVolumeClaim.claimName = "${appName}-pvc";
              }
              ++ (map (vol: {
                name = vol.name;
                emptyDir =
                  if vol.medium != null then
                    {
                      medium = vol.medium;
                    }
                    // lib.optionalAttrs (vol.sizeLimit != null) { sizeLimit = vol.sizeLimit; }
                  else
                    { };
              }) appCfg.emptyDirVolumes)
              ++ (map (vol: {
                name = vol.name;
                hostPath = {
                  path = vol.hostPath;
                }
                // lib.optionalAttrs (vol.type != null) { type = vol.type; };
              }) appCfg.hostPathVolumes)
              ++ appCfg.extraVolumes;
          };
        };
      };
    };

    mkService = namespace: appName: appCfg: {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "${appName}-service";
        inherit namespace;
      };

      spec = {
        selector.app = appName;
        ipFamilyPolicy = "SingleStack";
        ipFamilies = [ "IPv4" ];
        ports = [
          {
            name = "http";
            port = appCfg.port;
            targetPort = appCfg.port;
            protocol = "TCP";
          }
        ]
        ++ (map (p: {
          name = p.name;
          port = p.containerPort;
          targetPort = p.containerPort;
          protocol = p.protocol;
        }) appCfg.ports);
        type = appCfg.service.type;
      }
      // lib.optionalAttrs (appCfg.service.loadBalancerIP != null) {
        loadBalancerIP = appCfg.service.loadBalancerIP;
      };
    };

    # Generate manifests for a single app
    mkAppManifests =
      stackName: stackCfg: appName: appCfg:
      let
        baseManifests =
          lib.optionalAttrs (appCfg.env != { }) {
            "${stackName}-${appName}-configmap" = mkConfigMap stackCfg.namespace appName appCfg.env;
          }
          // lib.optionalAttrs (appCfg.storage != null) {
            "${stackName}-${appName}-pv" =
              mkPersistentVolume stackCfg.storageClass appName appCfg.storage.path
                appCfg.storage.size;

            "${stackName}-${appName}-pvc" =
              mkPersistentVolumeClaim stackCfg.namespace stackCfg.storageClass appName
                appCfg.storage.size;
          }
          // {
            "${stackName}-${appName}-deployment" = mkDeployment stackCfg.namespace appName (
              if appCfg.useSharedStorage && stackCfg.sharedStorage != null then
                appCfg
                // {
                  extraVolumes = appCfg.extraVolumes ++ [
                    {
                      name = "shared-storage";
                      persistentVolumeClaim.claimName = stackCfg.sharedStorage.pvcName;
                    }
                  ];

                  extraVolumeMounts = appCfg.extraVolumeMounts ++ [
                    {
                      name = "shared-storage";
                      mountPath = stackCfg.sharedStorage.mountPath;
                    }
                  ];
                }
              else
                appCfg
            );
            "${stackName}-${appName}-service" = mkService stackCfg.namespace appName appCfg;
          };
      in
      baseManifests;

    # Generate manifests for a stack
    generateStackManifests =
      stackName: stackCfg:
      let
        baseManifests = {
          "${stackName}-namespace" = {
            apiVersion = "v1";
            kind = "Namespace";
            metadata.name = stackCfg.namespace;
          };

          "${stackName}-storageclass" = {
            apiVersion = "storage.k8s.io/v1";
            kind = "StorageClass";
            metadata.name = stackCfg.storageClass;
            provisioner = "kubernetes.io/no-provisioner";
            volumeBindingMode = "WaitForFirstConsumer";
            reclaimPolicy = "Retain";
            allowVolumeExpansion = true;
          };
        }
        // lib.optionalAttrs (stackCfg.sharedStorage != null) {
          "${stackName}-shared-pv" =
            mkPersistentVolume stackCfg.storageClass stackCfg.sharedStorage.pvName stackCfg.sharedStorage.path
              stackCfg.sharedStorage.size;

          "${stackName}-shared-pvc" =
            mkPersistentVolumeClaim stackCfg.namespace stackCfg.storageClass stackCfg.sharedStorage.pvName
              stackCfg.sharedStorage.size;
        };

        appManifests = lib.foldl' (
          acc: appName:
          let
            appCfg = stackCfg.apps.${appName};
          in
          if appCfg.enable then acc // mkAppManifests stackName stackCfg appName appCfg else acc
        ) { } (builtins.attrNames stackCfg.apps);
      in
      baseManifests // appManifests;

    # Get all k3s stacks from config
    allStacks = config.telometto.k3s.stacks or { };
    k3sStacks = lib.filterAttrs (name: cfg: (cfg.enable or false)) allStacks;

    # Generate all manifests
    allManifests = lib.foldl' (
      acc: stackName: acc // generateStackManifests stackName k3sStacks.${stackName}
    ) { } (builtins.attrNames k3sStacks);

  in
  {
    options.telometto.k3s.stacks = lib.mkOption {
      type = lib.types.attrsOf stackType;
      default = { };
      description = ''
        K3s app stacks. Each stack will be deployed to the k3s cluster.
      '';
    };

    config = lib.mkIf (allManifests != { }) {
      assertions = [
        {
          assertion = config.telometto.services.k3s.enable or false;
          message = "k3s must be enabled to use k3s app stacks";
        }
      ];

      services.k3s.manifests = allManifests;
    };
  }
*/
