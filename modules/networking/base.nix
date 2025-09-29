{ lib, config, ... }:
let
  cfg = config.telometto.networking.base;
in
{
  options.telometto.networking.base.enable = lib.mkEnableOption "Base networking defaults";

  config = lib.mkIf cfg.enable {
    networking = {
      wireless.enable = lib.mkDefault false;
    };
  };
}
