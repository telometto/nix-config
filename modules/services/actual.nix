{ lib, config, ... }:
let
  cfg = config.sys.services.actual or { };
in
{
  options.sys.services.actual = {
    enable = lib.mkEnableOption "Actual Budget";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3838;
    };
  };

  config = lib.mkIf cfg.enable {
    services.actual = {
      enable = lib.mkDefault true;
      openFirewall = lib.mkDefault false;
      settings.port = cfg.port;
    };
  };
}
