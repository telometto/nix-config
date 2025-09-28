{ lib, config, ... }:
let cfg = config.telometto.services.jellyfin;
in {
  options.telometto.services.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin service";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall for Jellyfin";
    };
  };

  config = lib.mkIf cfg.enable {
    services.jellyfin = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };
  };
}
