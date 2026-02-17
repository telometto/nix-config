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
    ../modules/services/firefox.nix
    ../modules/virtualisation/virtualisation.nix
    inputs.sops-nix.nixosModules.sops
  ];

  # SOPS configuration for this MicroVM
  # After first boot, derive the VM's age public key without copying the private key:
  #   ssh admin@10.100.0.52 "sudo ssh-keygen -y -f /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add the resulting age public key to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];

    # Run sops-install-secrets as a systemd service (after local-fs.target)
    # instead of activation script, since /persist isn't mounted during activation
    useSystemdActivation = true;

    secrets = {
      "firefox/user" = { };
      "firefox/password" = { };
    };
  };

  sys.secrets = {
    firefoxUser = config.sops.secrets."firefox/user".path;
    firefoxPassword = config.sops.secrets."firefox/password".path;
  };

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 115;

    mem = 4096;
    vcpu = 4;

    volumes = [
      {
        mountPoint = "/var/lib/firefox";
        image = "firefox-state.img";
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
        id = "vm-firefox";
        mac = "02:00:00:00:00:10";
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

      firefox = {
        enable = true;

        dataDir = "/var/lib/firefox";
        httpPort = 11052;
        httpsPort = 11053;
        networkMode = "bridge";
        timeZone = "Europe/Oslo";
        title = "Firefox";
        openFirewall = false;

        customUserFile = config.sys.secrets.firefoxUser;
        passwordFile = config.sys.secrets.firefoxPassword;
      };
    };
  };

  networking = {
    hostName = "firefox-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        11052
        11053
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
          Address = [ "10.100.0.52/24" ];
          Gateway = "10.100.0.11"; # Route through Wireguard VM for VPN kill switch
          DNS = [ "1.1.1.1" ];
          DHCP = "no";
        };
        # Explicit routes to reach the LAN and microvm bridge via the host gateway,
        # since the default gateway points to the WireGuard VM (10.100.0.11)
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

    # Use persistent storage for image pull temp files instead of tmpfs
    services.podman-firefox.environment.TMPDIR = "/var/lib/containers/tmp";
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
