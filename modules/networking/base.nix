{ lib, config, ... }:
let
  cfg = config.sys.networking.base;
in
{
  options.sys.networking.base.enable = lib.mkEnableOption "Base networking defaults";

  config = lib.mkIf cfg.enable {
    networking = {
      wireless.enable = lib.mkDefault false;
    };
  };
}
