{ lib, config, ... }:
let cfg = config.telometto.services.cockpit or { };
in {
  options.telometto.services.cockpit = {
    enable = lib.mkEnableOption "Cockpit web UI";
    port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
    };
  };
  config = lib.mkIf cfg.enable {
    services.cockpit = {
      enable = true;
      inherit (cfg) port;
      openFirewall = true;
      settings.WebService.AllowUnencrypted = true;
    };
  };
}
