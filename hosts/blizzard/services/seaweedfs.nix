{ config, consts, ... }:
{
  sys.services.seaweedfs = {
    enable = false;

    ip = "127.0.0.1";

    tailscale = {
      enable = true;
      hostname = "${config.networking.hostName}.${consts.tailscale.suffix}";
    };

    configDir = "/rpool/unenc/apps/nixos/seaweedfs/config";

    master.dataDir = "/rpool/unenc/apps/nixos/seaweedfs/master";
    master.port = consts.seaweedfsMasterPort;

    volume = {
      dataDir = "/rpool/unenc/apps/nixos/seaweedfs/volume";
      port = consts.seaweedfsVolumePort;
      grpcPort = consts.seaweedfsGrpcPort;
    };

    filer = {
      dataDir = "/rpool/unenc/apps/nixos/seaweedfs/filer";
      port = consts.seaweedfsFilerPort;
    };

    s3 = {
      port = consts.seaweedfsS3Port;
      auth = {
        enable = true;
        accessKeyFile = config.sys.secrets.seaweedfsAccessKeyFile;
        secretAccessKeyFile = config.sys.secrets.seaweedfsSecretAccessKeyFile;
      };
    };

    metrics.port = consts.seaweedfsMetricsPort;
  };
}
