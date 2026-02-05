{ config, ... }:
{
  sys.services.seaweedfs = {
    enable = false;

    ip = "127.0.0.1";

    tailscale = {
      enable = true;
      hostname = "${config.networking.hostName}.mole-delta.ts.net";
    };

    configDir = "/rpool/unenc/apps/nixos/seaweedfs/config";

    master.dataDir = "/rpool/unenc/apps/nixos/seaweedfs/master";
    master.port = 11017;

    volume = {
      dataDir = "/rpool/unenc/apps/nixos/seaweedfs/volume";
      port = 11018;
      grpcPort = 11019;
    };

    filer = {
      dataDir = "/rpool/unenc/apps/nixos/seaweedfs/filer";
      port = 11020;
    };

    s3 = {
      port = 11021;
      auth = {
        enable = true;
        accessKeyFile = config.sys.secrets.seaweedfsAccessKeyFile;
        secretAccessKeyFile = config.sys.secrets.seaweedfsSecretAccessKeyFile;
      };
    };

    metrics.port = 11022;
  };
}
