{ VARS, ... }:
{
  sys.services = {paperless = {
    enable = false;

    consumptionDirIsPublic = true;
    consumptionDir = "/rpool/enc/personal/documents";
    mediaDir = "/rpool/enc/personal/paperless-media";
  };

  actual = {
    enable = false;

    port = 11005;
    dataDir = "/rpool/unenc/apps/nixos/actual";
  };

  firefly.enable = false;

  immich = {
    enable = false;

    host = "0.0.0.0";
    port = 11007;
    openFirewall = true;
    mediaLocation = "/flash/enc/personal/immich-library";
    secretsFile = "/opt/sec/immich-file";
    environment = {
      IMMICH_LOG_LEVEL = "verbose";
      IMMICH_TELEMETRY_INCLUDE = "all";
    };
  };};
}
