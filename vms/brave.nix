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
    ../modules/services/brave.nix
    ../modules/virtualisation/virtualisation.nix
    inputs.sops-nix.nixosModules.sops
  ];

  # SOPS configuration for this MicroVM
  # After first boot, get the VM's age key with:
  #   ssh admin@10.100.0.54 "sudo cat /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add it to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "brave/user" = { };
      "brave/password" = { };
    };
  };

  sys.secrets = {
    braveUser = config.sops.secrets."brave/user".path;
    bravePassword = config.sops.secrets."brave/password".path;
  };

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 116;

    mem = 4096;
    vcpu = 4;

    volumes = [
      {
        mountPoint = "/var/lib/brave";
        image = "brave-state.img";
        size = 10240;
      }
      {
        mountPoint = "/var/lib/containers";
        image = "containers-storage.img";
        size = 4096;
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
        id = "vm-brave";
        mac = "02:00:00:00:00:11";
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

  sys = {
    virtualisation.enable = true;

    services = {
      nfs = {
        enable = true;

        mounts.media = {
          server = "10.100.0.1";
          export = "/rpool/unenc/media/data";
          target = "/data";
        };
      };

      brave = {
        enable = true;

        dataDir = "/var/lib/brave";
        httpPort = 11054;
        httpsPort = 11055;
        networkMode = "host";
        timeZone = "Europe/Oslo";
        title = "Brave";
        openFirewall = false;

        customUserFile = config.sys.secrets.braveUser;
        passwordFile = config.sys.secrets.bravePassword;
      };
    };
  };

  networking = {
    hostName = "brave-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        11054
        11055
      ];
    };
  };

  systemd = {
    network.networks = {
      "19-podman" = {
        matchConfig.Name = "veth*";
        linkConfig.Unmanaged = true;
      };

      "20-lan" = {
        matchConfig.Type = "ether";
        networkConfig = {
          Address = [ "10.100.0.54/24" ];
          Gateway = "10.100.0.11";
          DNS = [ "1.1.1.1" ];
          DHCP = "no";
        };
        routes = [
          {
            Gateway = "10.100.0.1";
            Destination = "192.168.0.0/16";
          }
          {
            Gateway = "10.100.0.1";
            Destination = "10.100.0.0/24";
          }
        ];
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
      "d /data 0750 root root -"
      "d /var/lib/containers/tmp 0750 root root -"
    ];

    services.podman-brave.environment.TMPDIR = "/var/lib/containers/tmp";
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

  security.sudo.wheelNeedsPassword = lib.mkForce false;

  system.stateVersion = "24.11";
}
