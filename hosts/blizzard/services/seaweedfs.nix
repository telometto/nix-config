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
    master.port = consts.ports.host.seaweedfsMaster;

    volume = {
      dataDir = "/rpool/unenc/apps/nixos/seaweedfs/volume";
      port = consts.ports.host.seaweedfsVolume;
      grpcPort = consts.ports.host.seaweedfsGrpc;
    };

    filer = {
      dataDir = "/rpool/unenc/apps/nixos/seaweedfs/filer";
      port = consts.ports.host.seaweedfsFiler;
    };

    s3 = {
      port = consts.ports.host.seaweedfsS3;
      auth = {
        enable = true;
        accessKeyFile = config.sys.secrets.seaweedfsAccessKeyFile;
        secretAccessKeyFile = config.sys.secrets.seaweedfsSecretAccessKeyFile;
      };
    };

    metrics.port = consts.ports.host.seaweedfsMetrics;
  };
}
