{ lib, config, ... }:
let cfg = config.telometto.services.firefly or { };
in {
  options.telometto.services.firefly.enable = lib.mkEnableOption "Firefly III";
  options.telometto.services.firefly.enableNginx = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };
  options.telometto.services.firefly.settings = lib.mkOption {
    type = lib.types.attrs;
    default = {
      APP_ENV = "local";
      APP_KEY_FILE = "/opt/sec/ff-file";
    };
  };

  config = lib.mkIf cfg.enable {
    services.firefly-iii = {
      enable = lib.mkDefault true;
      enableNginx = lib.mkDefault cfg.enableNginx;
      settings = cfg.settings;
    };
  };
}
