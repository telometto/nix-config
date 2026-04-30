{
  lib,
  config,
  inputs,
  VARS,
  ...
}:
let
  reg = (import ./vm-registry.nix).mealie;
in
{
  imports = [
    ./base.nix
    ../modules/services/mealie.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/mealie";
            image = "mealie-state.img";
            size = 51200;
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

  # After first boot, retrieve the VM age key:
  #   ssh admin@10.100.0.71 "sudo cat /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Add to .sops.yaml, encrypt mealie/credentials, then redeploy.
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets."mealie/credentials" = {
      mode = "0440";
      owner = "mealie";
      group = "mealie";
    };
  };

  users = {
    users.mealie = {
      isSystemUser = true;
      description = "Mealie service user";
      group = "mealie";
      home = "/var/lib/mealie";
    };
    groups.mealie = { };
  };

  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/mealie 0750 mealie mealie -"
      "d /var/lib/postgresql 0700 postgres postgres -"
    ];

    services.mealie = {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
      serviceConfig.DynamicUser = lib.mkForce false;
    };
  };

  services.nginx = {
    enable = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts."mealie" = {
      listen = [
        {
          addr = "0.0.0.0";
          inherit (reg) port;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.sys.services.mealie.port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          client_max_body_size 100M;
        '';
      };
    };
  };

  sys.services.mealie = {
    enable = true;
    credentialsFile = config.sops.secrets."mealie/credentials".path;

    reverseProxy = {
      enable = true;
      domain = "recipes.${VARS.domains.public}";
    };
  };
}
