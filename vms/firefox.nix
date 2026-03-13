{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  reg = (import ./vm-registry.nix).firefox;
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
        ];
        extraRoutes = vpnRoutes;
      }
    ))
  ];

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
    services.podman-firefox.environment.TMPDIR = "/var/lib/containers/tmp";
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

        customUserFile = config.sys.secrets.firefoxUser;
        passwordFile = config.sys.secrets.firefoxPassword;
      };
    };
  };
}
