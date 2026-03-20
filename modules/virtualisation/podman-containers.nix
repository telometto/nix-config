{
  lib,
  config,
  ...
}:
let
  cfg = config.sys.virtualisation.podman;

  containerModule = lib.types.submodule {
    options = {
      image = lib.mkOption {
        type = lib.types.str;
        description = "OCI image to run.";
      };

      autoStart = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to start this container automatically on boot. Defaults to the stack-level autoStart if unset.";
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables for this container.";
      };

      environmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ ];
        description = "Environment files for this container.";
      };

      volumes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "List of volume mounts (\"src:dst\" strings).";
      };

      ports = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Port mappings (\"host:container\" strings).";
      };

      dependsOn = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Other container names this one depends on.";
      };

      extraOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra CLI options passed to podman run.";
      };

      labels = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Labels to attach to the container.";
      };

      cmd = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Command arguments passed to the image entrypoint.";
      };

      entrypoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override the default entrypoint of the image.";
      };

      user = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override the username or UID used in the container.";
      };
    };
  };

  stackModule =
    { name, config, ... }:
    {
      options = {
        enable = lib.mkEnableOption "container stack '${name}'";

        autoStart = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Default autoStart for containers in this stack.";
        };

        containers = lib.mkOption {
          type = lib.types.attrsOf containerModule;
          default = { };
          description = "Containers in this stack.";
        };
      };
    };

  enabledStacks = lib.filterAttrs (_: stack: stack.enable) cfg.stacks;

  # Collect all container names per stack for duplicate detection
  allContainerNames = lib.flatten (
    lib.mapAttrsToList (
      stackName: stack:
      map (cName: {
        inherit stackName;
        name = cName;
      }) (builtins.attrNames stack.containers)
    ) enabledStacks
  );

  stackContainerNames = map (e: e.name) allContainerNames;

  duplicateNames = lib.unique (
    lib.filter (n: builtins.length (lib.filter (candidate: candidate == n) stackContainerNames) > 1) stackContainerNames
  );

  # Detect collisions between stack containers and non-stack oci-containers
  nonStackContainerNames = builtins.attrNames (
    builtins.removeAttrs
      (config.virtualisation.oci-containers.containers or { })
      stackContainerNames
  );

  stackVsNonStackCollisions = lib.filter
    (n: builtins.elem n nonStackContainerNames)
    (lib.unique stackContainerNames);

  # Merge all enabled stack containers into a single attrset for oci-containers
  mergedContainers = lib.mkMerge (
    lib.mapAttrsToList (
      _: stack:
      builtins.mapAttrs (
        _: c:
        {
          inherit (c)
            image
            environment
            environmentFiles
            volumes
            ports
            dependsOn
            extraOptions
            labels
            cmd
            ;
          autoStart = if c.autoStart != null then c.autoStart else stack.autoStart;
        }
        // lib.optionalAttrs (c.entrypoint != null) { inherit (c) entrypoint; }
        // lib.optionalAttrs (c.user != null) { inherit (c) user; }
      ) stack.containers
    ) enabledStacks
  );
in
{
  options.sys.virtualisation.podman.stacks = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule stackModule);
    default = { };
    description = ''
      Declarative Podman container stacks.
      Each stack groups related containers and is enabled per host.
      Enabled stacks are merged into virtualisation.oci-containers.containers.
    '';
  };

  config = lib.mkIf (enabledStacks != { }) {
    assertions = [
      {
        assertion = config.sys.virtualisation.enable;
        message = "sys.virtualisation.podman.stacks: sys.virtualisation.enable must be true when container stacks are enabled.";
      }
      {
        assertion = duplicateNames == [ ];
        message = "sys.virtualisation.podman.stacks: duplicate container names across stacks: ${lib.concatStringsSep ", " duplicateNames}";
      }
      {
        assertion = stackVsNonStackCollisions == [ ];
        message = "sys.virtualisation.podman.stacks: container names collide with non-stack oci-containers: ${lib.concatStringsSep ", " stackVsNonStackCollisions}";
      }
    ];

    virtualisation.oci-containers.containers = mergedContainers;
  };
}
