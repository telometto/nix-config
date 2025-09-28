{ lib, config, ... }:
let cfg = config.telometto.services.sanoid or { };
in {
  options.telometto.services.sanoid.enable =
    lib.mkEnableOption "Sanoid snapshot management";

  options.telometto.services.sanoid.templates = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = {
      production = {
        autosnap = true;
        autoprune = false;
        yearly = 4;
        monthly = 4;
        weekly = 3;
        daily = 4;
        hourly = 0;
      };
    };
    description = "Sanoid templates map";
  };

  options.telometto.services.sanoid.datasets = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
    description = "Datasets configuration referencing templates";
  };

  config = lib.mkIf cfg.enable {
    services.sanoid = {
      enable = true;
      templates = cfg.templates;
      datasets = cfg.datasets;
      settings = { };
    };
  };
}
