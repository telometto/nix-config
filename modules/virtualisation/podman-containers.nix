{
  lib,
  config,
  options,
  ...
}:
let
  cfg = config.sys.virtualisation.podman;

  stackModule =
    { name, ... }:
    {
      options = {
        enable = lib.mkEnableOption "container stack '${name}'";

        autoStart = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Default autoStart for containers in this stack.";
        };

        containers = lib.mkOption {
          type = lib.types.attrsOf lib.types.attrs;
          default = { };
          description = "Container configs passed through to virtualisation.oci-containers.containers.";
        };
      };
    };

  enabledStacks = lib.filterAttrs (_: s: s.enable) cfg.stacks;

  stackContainerNames = lib.concatMap (s: builtins.attrNames s.containers) (
    builtins.attrValues enabledStacks
  );

  duplicateNames = lib.unique (
    lib.filter (n: lib.count (x: x == n) stackContainerNames > 1) stackContainerNames
  );

  # Detect collisions with non-stack oci-containers by inspecting raw option
  # definitions — the merged config already includes this module's contributions.
  otherDefinedNames =
    lib.pipe (options.virtualisation.oci-containers.containers.definitionsWithLocations or [ ])
      [
        (builtins.filter (d: !(lib.hasInfix "podman-containers.nix" (d.file or ""))))
        (map (
          d:
          let
            r = builtins.tryEval (builtins.attrNames d.value);
          in
          if r.success then r.value else [ ]
        ))
        lib.flatten
        lib.unique
      ];

  stackVsNonStackCollisions = lib.filter (n: builtins.elem n otherDefinedNames) (
    lib.unique stackContainerNames
  );

  mergedContainers = lib.mkMerge (
    lib.mapAttrsToList (
      _: stack: builtins.mapAttrs (_: c: { autoStart = stack.autoStart; } // c) stack.containers
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
