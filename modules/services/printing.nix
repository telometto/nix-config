# OK
{ lib, config, ... }:
let cfg = config.telometto.services.printing;
in {
  options.telometto.services.printing.enable =
    lib.mkEnableOption "CUPS printing";
  config = lib.mkIf cfg.enable { services.printing.enable = true; };
}
