{
  lib,
  config,
  ...
}:
let
  cfg = config.sys.nix.distributedBuilds;

  buildMachineType = lib.types.submodule (_: {
    options = {
      hostName = lib.mkOption {
        type = lib.types.str;
        description = "Hostname or SSH target for the remote builder";
      };

      systems = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ config.nixpkgs.hostPlatform.system ];
        description = "Target systems the builder can handle (e.g., x86_64-linux)";
      };

      sshUser = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "User used to connect to the builder";
      };

      sshKey = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to SSH key used for connecting to the builder";
      };

      maxJobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4;
        description = "Maximum parallel jobs allowed on the builder";
      };

      speedFactor = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = "Relative speed weighting for this builder";
      };

      supportedFeatures = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Optional supported features (e.g., kvm, big-parallel)";
      };

      mandatoryFeatures = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Features required for a job to run on this builder";
      };

      protocol = lib.mkOption {
        type = lib.types.enum [ "ssh" "ssh-ng" ];
        default = "ssh";
        description = "Protocol used to reach the builder";
      };
    };
  });

  renderMachine = machine:
    lib.filterAttrs (_: v: v != null) {
      inherit (machine)
        hostName
        systems
        maxJobs
        speedFactor
        sshUser
        supportedFeatures
        mandatoryFeatures
        protocol;
      sshKey = machine.sshKey;
    };

in
{
  options.sys.nix.distributedBuilds = {
    enable = lib.mkEnableOption "Enable distributed builds using remote build machines";

    buildersUseSubstitutes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow remote builders to use configured substituters";
    };

    buildMachines = lib.mkOption {
      type = lib.types.listOf buildMachineType;
      default = [ ];
      description = "Remote builders available for distributed builds";
      example = lib.literalExpression "[ { hostName = \"builder\"; systems = [ \"x86_64-linux\" ]; maxJobs = 8; speedFactor = 2; sshUser = \"root\"; } ]";
    };

    server = {
      enable = lib.mkEnableOption "Expose this host as a remote builder via nix.sshServe";

      write = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow remote clients to push store paths (required for builds)";
      };

      keys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Authorized SSH public keys allowed to submit builds to nix.sshServe";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      nix.distributedBuilds = true;
      nix.settings.builders-use-substitutes = lib.mkDefault cfg.buildersUseSubstitutes;
      nix.buildMachines = map renderMachine cfg.buildMachines;
    })

    (lib.mkIf cfg.server.enable {
      services.openssh.enable = lib.mkDefault true;

      nix.sshServe = {
        enable = true;
        inherit (cfg.server) keys write;
        protocol = "ssh";
      };
    })
  ];
}
