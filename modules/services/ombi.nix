{ lib, config, VARS, ... }:
let cfg = config.telometto.services.ombi or { };
in {
  options.telometto.services.ombi.enable = lib.mkEnableOption "Ombi";
  options.telometto.services.ombi.dataDir = lib.mkOption {
    type = lib.types.str;
    default = "/rpool/unenc/apps/nixos/ombi";
  };
  options.telometto.services.ombi.openFirewall = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf cfg.enable {
    services.ombi = {
      enable = true;
      dataDir = cfg.dataDir;
      openFirewall = cfg.openFirewall;
    };
  };
}
