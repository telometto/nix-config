{ lib, config, ... }:
let
  cfg = config.sys.services.firefly or { };
in
{
  options.sys.services.firefly = {
    enable = lib.mkEnableOption "Firefly III";
    enableNginx = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        APP_ENV = "local";
        APP_KEY_FILE = "/opt/sec/ff-file";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.firefly-iii = {
      enable = lib.mkDefault true;

      inherit (cfg) settings enableNginx;
    };
  };
}
