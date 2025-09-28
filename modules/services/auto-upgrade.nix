{ lib, config, ... }:
let cfg = config.telometto.services.autoUpgrade or { };
in {
  options.telometto.services.autoUpgrade = {
    enable = lib.mkEnableOption "Automatic system upgrades via flakes";
    flake = lib.mkOption {
      type = lib.types.str;
      default = "github:telometto/nix-config";
      description = "Flake URL to update from";
    };
    operation = lib.mkOption {
      type = lib.types.str;
      default = "boot";
    }; # apply on next boot
    dates = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
    };
    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
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
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      flake = cfg.flake;
      operation = cfg.operation;
      flags = cfg.flags;
      dates = cfg.dates;
      rebootWindow = cfg.rebootWindow;
      persistent = cfg.persistent;
      allowReboot = cfg.allowReboot;
      fixedRandomDelay = cfg.fixedRandomDelay;
      randomizedDelaySec = cfg.randomizedDelaySec;
    };
  };
}
