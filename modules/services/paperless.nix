{ lib, config, ... }:
let cfg = config.telometto.services.paperless or { };
in {
  options.telometto.services.paperless.enable =
    lib.mkEnableOption "Paperless-ngx";
  options.telometto.services.paperless.address = lib.mkOption {
    type = lib.types.str;
    default = "0.0.0.0";
  };
  options.telometto.services.paperless.port = lib.mkOption {
    type = lib.types.port;
    default = 28981;
  };
  options.telometto.services.paperless.consumptionDir = lib.mkOption {
    type = lib.types.str;
    default = "/rpool/enc/personal/documents";
  };
  options.telometto.services.paperless.mediaDir = lib.mkOption {
    type = lib.types.str;
    default = "/rpool/enc/personal/paperless-media";
  };
  options.telometto.services.paperless.passwordFile = lib.mkOption {
    type = lib.types.path;
    # Use centralized secrets bridge; avoids direct SOPS references here
    default = config.telometto.secrets.paperlessKeyFile;
  }; # allow null
  options.telometto.services.paperless.consumptionDirIsPublic = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = lib.mkIf cfg.enable {
    services.paperless = {
      enable = true;
      address = cfg.address;
      port = cfg.port;
      consumptionDir = cfg.consumptionDir;
      mediaDir = cfg.mediaDir;
      passwordFile = cfg.passwordFile;
      consumptionDirIsPublic = cfg.consumptionDirIsPublic;
    };
  };
}
