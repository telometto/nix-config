{
  lib,
  config,
  inputs,
  ...
}:
let
  reg = (import ./vm-registry.nix).firefly;
in
{
  imports = [
    ./base.nix
    ../modules/services/firefly.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/firefly-iii";
            image = "firefly-iii-state.img";
            size = 10240;
          }
          {
            mountPoint = "/var/lib/postgresql";
            image = "postgresql-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets = {
      "firefly/app_key" = {
        mode = "0440";
        owner = "firefly-iii";
        group = "firefly-iii";
      };
    };
  };

  sys.secrets.fireflyAppKeyFile = config.sops.secrets."firefly/app_key".path;

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/firefly-iii 0700 firefly-iii firefly-iii -"
      "d /var/lib/postgresql 0700 postgres postgres -"
    ];

    services.firefly-iii-setup = {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
    };
  };

  sys.services.firefly = {
    enable = true;

    reverseProxy.enable = false;

    settings = {
      ALLOW_WEBHOOKS = false;
      COOKIE_SECURE = "true";
      SEND_REGISTRATION_MAIL = true;
      SEND_LOGIN_NEW_IP_WARNING = true;
    };
  };

  # Outer Nginx listens on 11062 and proxies to Firefly's PHP-FPM Nginx on :80
  services.nginx.virtualHosts."firefly".listen = lib.mkForce [
    {
      addr = "0.0.0.0";
      port = reg.port;
    }
  ];
}
