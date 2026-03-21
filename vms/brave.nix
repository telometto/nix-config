{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  reg = (import ./vm-registry.nix).brave;
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
    ../modules/services/brave.nix
    ../modules/virtualisation/virtualisation.nix
    inputs.sops-nix.nixosModules.sops
    inputs.quadlet-nix.nixosModules.quadlet
    (import ./mkMicrovmConfig.nix (
      reg
      // {
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
        ];
        extraRoutes = vpnRoutes;
      }
    ))
  ];

  # SOPS configuration for this MicroVM
  # After first boot, derive the VM's age public key without copying the private key:
  #   ssh admin@10.100.0.54 "sudo ssh-keygen -y -f /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add the resulting age public key to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets = {
      "brave/user" = { };
      "brave/password" = { };
    };
  };

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  networking.firewall.allowedTCPPorts = [
    reg.port
    11055
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

    services.brave.environment.TMPDIR = "/var/lib/containers/tmp";
  };

  sys = {
    secrets = {
      braveUser = config.sops.secrets."brave/user".path;
      bravePassword = config.sops.secrets."brave/password".path;
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

      brave = {
        enable = true;

        dataDir = "/var/lib/brave";
        httpPort = reg.port;
        httpsPort = 11055;
        networkMode = "bridge";
        timeZone = "Europe/Oslo";
        title = "Brave";
        openFirewall = false;

        customUserFile = config.sys.secrets.braveUser;
        passwordFile = config.sys.secrets.bravePassword;
      };
    };
  };
}
