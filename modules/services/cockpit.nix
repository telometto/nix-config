{ lib, config, ... }:
let cfg = config.telometto.services.cockpit or { };
in {
  options.telometto.services.cockpit.enable =
    lib.mkEnableOption "Cockpit web UI";
  options.telometto.services.cockpit.port = lib.mkOption {
    type = lib.types.port;
    default = 9090;
  };
  config = lib.mkIf cfg.enable {
    services.cockpit = {
      enable = true;
      port = cfg.port;
      openFirewall = true;
      settings.WebService.AllowUnencrypted = true;
    };
  };
}
