{ lib, config, ... }:
let
  cfg = config.telometto.services.paperless or { };
in
{
  options.telometto.services.paperless = {
    enable = lib.mkEnableOption "Paperless-ngx";
    address = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 28981;
    };
    consumptionDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/enc/personal/documents";
    };
    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/rpool/enc/personal/paperless-media";
    };
    passwordFile = lib.mkOption {
      type = lib.types.path;
      # Use centralized secrets bridge; avoids direct SOPS references here
      default = config.telometto.secrets.paperlessKeyFile;
    }; # allow null
    consumptionDirIsPublic = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.paperless = {
      enable = true;
      inherit (cfg)
        address
        port
        consumptionDir
        mediaDir
        passwordFile
        consumptionDirIsPublic
        ;
    };
  };
}
