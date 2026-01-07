{ lib, config, ... }:
let
  cfg = config.sys.services.teamviewer;
in
{
  options.sys.services.teamviewer.enable = lib.mkEnableOption "TeamViewer remote support";

  config = lib.mkIf cfg.enable { services.teamviewer.enable = true; };
}
