{ lib, config, ... }:
let cfg = config.telometto.services.teamviewer;
in {
  options.telometto.services.teamviewer.enable =
    lib.mkEnableOption "TeamViewer remote support";
  config = lib.mkIf cfg.enable { services.teamviewer.enable = true; };
}
