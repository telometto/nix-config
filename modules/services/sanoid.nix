{ lib, config, ... }:
let
  cfg = config.telometto.services.sanoid or { };
in
{
  options.telometto.services.sanoid = {
    enable = lib.mkEnableOption "Sanoid snapshot management";

    templates = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = {
        production = {
          autosnap = true;
          autoprune = false;
          yearly = 2;
          monthly = 6;
          weekly = 4;
          daily = 7;
          hourly = 0;
        };
      };
      description = "Sanoid templates map";
    };

    datasets = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Datasets configuration referencing templates";
    };
  };

  config = lib.mkIf cfg.enable {
    services.sanoid = {
      enable = true;
      inherit (cfg) templates datasets;
      settings = { };
    };
  };
}
