{ lib, config, ... }:
let
  cfg = config.sys.services.autoUpgrade or { };
in
{
  options.sys.services.autoUpgrade = {
    enable = lib.mkEnableOption "Automatic system upgrades via flakes";

    flake = lib.mkOption {
      type = lib.types.str;
      default = "github:telometto/nix-config";
      description = "Flake URL to update from";
    };

    operation = lib.mkOption {
      type = lib.types.str;
      default = "boot";
      description = "The operation to perform (switch or boot)";
    };

    dates = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "How often to run the upgrade (systemd calendar format)";
    };

    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional flags to pass to nixos-rebuild";
    };

    rebootWindow = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        lower = "00:00";
        upper = "02:30";
      };

      description = "Allowed reboot window";
    };

    persistent = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    fixedRandomDelay = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "20min";
    };

    upgrade = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    runGc = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run garbage collection after a successful upgrade."
    };

    sshKeyPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/etc/ssh/ssh_host_ed25519_key";
      description = "Path to SSH key for git operations (for private repos). Defaults to host key.";
      example = "/root/.ssh/id_ed25519_deploy";
    };
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      inherit (cfg)
        flake
        operation
        flags
        dates
        rebootWindow
        persistent
        allowReboot
        fixedRandomDelay
        randomizedDelaySec
        upgrade
        ;

        runGc = cfg.runGarbageCollection;
    };

    systemd.services.nixos-upgrade = lib.mkIf (cfg.sshKeyPath != null) {
      environment.GIT_SSH_COMMAND = "ssh -i ${cfg.sshKeyPath} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new";
    };
  };
}
