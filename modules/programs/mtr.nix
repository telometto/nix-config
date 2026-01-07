{ lib, config, ... }:
let
  cfg = config.sys.programs.mtr;
in
{
  options.sys.programs.mtr.enable = lib.mkEnableOption "Enable mtr with SUID wrapper";
  config = lib.mkIf cfg.enable { programs.mtr.enable = lib.mkDefault true; };
}
