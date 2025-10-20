{ lib, config, ... }:
let
  cfg = config.telometto.services.ombi or { };
in
{
  options.telometto.services.ombi = {
    enable = lib.mkEnableOption "Ombi";
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/unenc/apps/nixos/ombi";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    services.ombi = {
      enable = true;
      inherit (cfg) dataDir openFirewall;
    };
  };
}
