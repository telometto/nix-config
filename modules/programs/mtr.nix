{ lib, config, ... }:
let cfg = config.telometto.programs.mtr;
in {
  options.telometto.programs.mtr.enable =
    lib.mkEnableOption "Enable mtr with SUID wrapper";
  config = lib.mkIf cfg.enable { programs.mtr.enable = lib.mkDefault true; };
}
