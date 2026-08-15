{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  reg = (import ./vm-registry.nix).firefox;
  transferDir = "/home/admin/Downloads";
  vpnRoutes = [
    {
      Gateway = "10.100.0.1";
      Destination = "192.168.0.0/16";
    }
    {
      Gateway = "10.100.0.1";
      Destination = "10.100.0.0/24";
    }
  ];
in
{
  imports = [
    ./base.nix
    ../modules/services/firefox.nix
    ../modules/virtualisation/virtualisation.nix
    inputs.sops-nix.nixosModules.sops
    inputs.quadlet-nix.nixosModules.quadlet
    (import ./mkMicrovmConfig.nix (
      reg
      // {
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
            mountPoint = transferDir;
            image = "firefox-downloads.img";
            size = 524288;
          }
        ];
        extraRoutes = vpnRoutes;
      }
    ))
  ];

  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  # SOPS configuration for this MicroVM
  # After first boot, derive the VM's age public key without copying the private key:
  #   ssh admin@10.100.0.52 "sudo ssh-keygen -y -f /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add the resulting age public key to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets = {
      "firefox/user" = { };
      "firefox/password" = { };
    };
  };

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  networking.firewall.allowedTCPPorts = [
    reg.port
    11053
  ];

  systemd = {
    network.networks."19-podman" = {
      matchConfig.Name = "veth*";
      linkConfig.Unmanaged = true;
    };

    tmpfiles.rules = [
      "d /data 0750 root root -"
      "d /var/lib/containers/tmp 0750 root root -"
    ];

    # Use persistent storage for image pull temp files instead of tmpfs
    services.firefox.environment.TMPDIR = "/var/lib/containers/tmp";
  };

  users.groups.firefox-downloads.gid = 1000;
  users.users.admin = {
    uid = 1000;
    extraGroups = lib.mkAfter [ "firefox-downloads" ];
  };

  sys = {
    secrets = {
      firefoxUser = config.sops.secrets."firefox/user".path;
      firefoxPassword = config.sops.secrets."firefox/password".path;
    };

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
        httpPort = reg.port;
        httpsPort = 11053;
        networkMode = "bridge";
        timeZone = "Europe/Oslo";
        title = "Firefox";
        openFirewall = false;

        fileTransfer = {
          enable = true;
          hostPath = transferDir;
          containerPath = "/downloads";
          hostUid = 1000;
          sharedGid = 1000;
          # LinuxServer's existing abc user owns the Firefox profile at UID
          # 911. Only its group identity is shared with the VM Downloads
          # directory; do not make the whole container run as admin (1000).
          containerUid = 911;
        };

        customUserFile = config.sys.secrets.firefoxUser;
        passwordFile = config.sys.secrets.firefoxPassword;
      };
    };
  };
}
