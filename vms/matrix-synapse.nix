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
    ../modules/services/matrix-synapse.nix
    inputs.sops-nix.nixosModules.sops
  ];

  # After first boot, get the VM's age key with:
  #   ssh admin@10.100.0.60 "sudo cat /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add it to .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    # Run sops-install-secrets as a systemd service (after local-fs.target)
    # instead of activation script, since /persist isn't mounted during activation
    useSystemdActivation = true;

    secrets = {
      "matrix-synapse/registration_shared_secret" = {
        mode = "0440";
        owner = "matrix-synapse";
        group = "matrix-synapse";
      };
    };
  };

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 119;

    mem = 2048;
    vcpu = 2;

    volumes = [
      {
        mountPoint = "/var/lib/matrix-synapse";
        image = "matrix-synapse-state.img";
        size = 20480;
      }
      {
        mountPoint = "/var/lib/postgresql";
        image = "postgresql-state.img";
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
        id = "vm-matrix";
        mac = "02:00:00:00:00:14";
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
    hostName = "matrix-synapse-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall.enable = true;
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.60/24" ];
        Gateway = "10.100.0.1";
        DNS = [ "1.1.1.1" ];
        DHCP = "no";
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
      "d /var/lib/matrix-synapse 0700 matrix-synapse matrix-synapse -"
      "d /var/lib/postgresql 0700 postgres postgres -"
    ];

    services.matrix-synapse = {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
    };
  };

  sys.services.matrix-synapse = {
    enable = true;

    port = 11060;
    serverName = "zzxyz.no";
    openFirewall = true;

    database.createLocally = true;
    urlPreview.enable = true;

    extraConfigFiles = [
      config.sops.secrets."matrix-synapse/registration_shared_secret".path
    ];

    reverseProxy.enable = false;
  };

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

  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  system.stateVersion = "24.11";
}
