{
  lib,
  config,
  inputs,
  VARS,
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
        group = "nginx";
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

  # nb_NO.UTF-8 must be present on the host or Firefly III raises an "unsupported locale" warning
  i18n.supportedLocales = [
    "nb_NO.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
  ];

  sys.services.firefly = {
    enable = true;

    reverseProxy = {
      enable = true;
      domain = "finance.${VARS.domains.public}";
    };

    settings = {
      ALLOW_WEBHOOKS = false;
      COOKIE_SECURE = "true";
      SEND_REGISTRATION_MAIL = true;
      SEND_LOGIN_NEW_IP_WARNING = true;
      DEFAULT_LOCALE = "nb_NO";
    };
  };

  security.sudo.wheelNeedsPassword = lib.mkForce false;

  services.nginx.virtualHosts."firefly".listen = lib.mkForce [
    {
      addr = "0.0.0.0";
      inherit (reg) port;
    }
  ];
}
