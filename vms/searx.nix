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
    ../modules/services/searx.nix
    ../modules/security/secrets.nix
    ../modules/core/overlays.nix
  ];

  config = {
    # sys.overlays.fromInputs = {
    #   nixpkgs-stable = [ "searxng" ];
    # };

    microvm = {
      hypervisor = "cloud-hypervisor";

      # CID must be unique per VM (3+ range, 0-2 are reserved)
      vsock.cid = 102;

      # 2GiB RAM for SearXNG
      mem = 2048;
      vcpu = 1;

      volumes = [
        {
          mountPoint = "/var/lib/searx";
          image = "searx-state.img";
          size = 1024;
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
          id = "vm-searx";
          mac = "02:00:00:00:00:03";
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
      hostName = "searx-vm";

      useDHCP = false;
      useNetworkd = true;

      firewall = {
        enable = true;
        allowedTCPPorts = [ 11012 ];
      };
    };

    systemd = {
      network.networks."20-lan" = {
        matchConfig.Type = "ether";
        networkConfig = {
          Address = [ "10.100.0.12/24" ];
          Gateway = "10.100.0.1";
          DNS = [ "1.1.1.1" ];
          DHCP = "no";
        };
      };

      tmpfiles.rules = [
        "d /persist/ssh 0700 root root -"
        "d /persist/searx 0700 root root -"
      ];

      services.searx-secret-key = {
        description = "Generate SearxNG secret key";
        before = [ "searx.service" ];
        requiredBy = [ "searx.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          install -d -m 0700 /persist/searx
          if [ ! -s /persist/searx/secret_key ]; then
            umask 077
            ${pkgs.openssl}/bin/openssl rand -hex 32 > /persist/searx/secret_key
          fi
        '';
      };
    };

    sys = {
      secrets.searxSecretKeyFile = "/persist/searx/secret_key";

      services.searx = {
        enable = true;
        port = 11012;
        bind = "0.0.0.0";

        reverseProxy = {
          enable = false;
        };
      };
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
  };
}
