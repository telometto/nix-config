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
        type = lib.types.bool;
        default = true;
        description = "Whether to start this container automatically on boot.";
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

  duplicateNames =
    let
      names = map (e: e.name) allContainerNames;
    in
    lib.unique (
      lib.filter (n: builtins.length (lib.filter (candidate: candidate == n) names) > 1) names
    );

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
          autoStart = c.autoStart;
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
        assertion = duplicateNames == [ ];
        message = "sys.virtualisation.podman.stacks: duplicate container names across stacks: ${lib.concatStringsSep ", " duplicateNames}";
      }
    ];

    virtualisation.oci-containers.containers = mergedContainers;
  };
}
