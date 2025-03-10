{ config, lib, pkgs, ... }:

{
  #environment.etc."paperlessFile".text = "admin";

  services.paperless = {
    enable = true;

    address = "0.0.0.0"; # Defaults to localhost
    # port = ; # Defaults to 28981

    # openMPThreadingWorkaround = true; # Defaults to true
    consumptionDirIsPublic = true; # Defaults to false

    consumptionDir = "/rpool/enc/personal/documents"; # Defaults to "/var/lib/paperless/consumption"
    # dataDir = "/rpool/unenc/apps/nixos/paperless-ngx";
    mediaDir = "/rpool/enc/personal/paperless-media"; # Defaults to "${dataDir}/media"
    passwordFile = config.sops.secrets."general/paperlessKeyFilePath".path; # config.sops.secrets.paperlessKeyFilePath.path;

    /* The following configuration does not work
      settings = {
      PAPERLESS_OCR_LANGUAGE = "eng+nor+ita";
      #PAPERLESS_OCR_LANGUAGES = "eng+nor+ita";

      PAPERLESS_CONSUMER_IGNORE_PATTERN = builtins.toJSON [
        ".DS_STORE/*"
        "desktop.ini"
      ];

      PAPERLESS_OCR_USER_ARGS = builtins.toJSON {
        optimize = 1;
        pdfa_image_compression = "lossless";
      };

      PAPERLESS_TIKA_ENABLED = true;
      };
    */
  };

  sops.secrets."general/paperlessKeyFilePath" = { };

  environment.systemPackages = with pkgs; [ paperless-ngx ];
}
