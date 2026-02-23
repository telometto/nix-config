{ lib, config, ... }:
let
  cfg = config.sys.services.printing;
in
{
  options.sys.services.printing.enable = lib.mkEnableOption "CUPS printing";

  config = lib.mkIf cfg.enable { services.printing.enable = true; };
}
