{ lib, config, ... }:
let cfg = config.telometto.services.actual or { };
in {
  options.telometto.services.actual.enable = lib.mkEnableOption "Actual Budget";
  options.telometto.services.actual.port = lib.mkOption {
    type = lib.types.port;
    default = 3838;
  };
  config = lib.mkIf cfg.enable {
    services.actual = {
      enable = lib.mkDefault true;
      openFirewall = lib.mkDefault true;
      settings.port = cfg.port;
    };
  };
}
