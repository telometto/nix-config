{
  lib,
  config,
  pkgs,
  inputs,
  VARS,
  ...
}:
{
  imports = [
    ./base.nix
    ../modules/services/gitea.nix
  ];

  networking.hostName = "gitea-vm";

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 106;

    mem = 2048;
    vcpu = 2;

    volumes = [
      {
        mountPoint = "/var/lib/gitea";
        image = "gitea-state.img";
        size = 10240;
      }
      {
        mountPoint = "/persist";
        image = "persist.img";
        size = 64;
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = "vm-gitea";
        mac = "02:00:00:00:00:07";
      }
    ];

    shares = [
      {
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag = "ro-store";
        proto = "virtiofs";
      }
    ];
  };

  networking = {
    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        11015
        2222
      ];
    };
  };

  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [ "10.100.0.16/24" ];
      Gateway = "10.100.0.1";
      DNS = [ "1.1.1.1" ];
      DHCP = "no";
    };
  };

  sys.services.gitea = {
    enable = true;
    port = 11015;
    stateDir = "/var/lib/gitea";
    repositoryRoot = "/var/lib/gitea/repositories";

    database = {
      type = "postgres";
      createDatabase = true;
    };

    lfs = {
      enable = true;
      allowPureSSH = true;
      s3Backend.enable = false;
    };

    disableRegistration = true;

    reverseProxy.enable = false;

    settings = {
      server = {
        ROOT_URL = "https://git.${VARS.domains.public}/";
        START_SSH_SERVER = true;
        SSH_DOMAIN = "ssh-git.${VARS.domains.public}";
        SSH_LISTEN_HOST = "0.0.0.0";
        SSH_LISTEN_PORT = 2222;
      };

      session.COOKIE_SECURE = true;
    };
  };

  systemd.tmpfiles.rules = [
    "d /persist/ssh 0700 root root -"
  ];

  services.openssh.hostKeys = [
    {
      path = "/persist/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/persist/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      VARS.users.zeno.sshPubKey
    ];
  };

  system.stateVersion = "24.11";
}
