{
  lib,
  config,
  inputs,
  pkgs,
  VARS,
  ...
}:
let
  reg = (import ./vm-registry.nix)."firefly-importer";
  fireflyUrl = "https://finance.${VARS.domains.public}";
in
{
  imports = [
    ./base.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/firefly-iii-data-importer";
            image = "firefly-iii-data-importer-state.img";
            size = 2048;
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
      "firefly/eb_app_id" = {
        mode = "0400";
        owner = "firefly-iii-data-importer";
        group = "nginx";
      };

      "firefly/eb_key" = {
        mode = "0400";
        owner = "firefly-iii-data-importer";
        group = "nginx";
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ reg.port ];

    extraCommands = ''
      ${pkgs.iptables}/bin/iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      ${pkgs.iptables}/bin/iptables -A OUTPUT -d 10.0.0.0/8 -m conntrack --ctstate NEW -j REJECT
      ${pkgs.iptables}/bin/iptables -A OUTPUT -d 172.16.0.0/12 -m conntrack --ctstate NEW -j REJECT
      ${pkgs.iptables}/bin/iptables -A OUTPUT -d 192.168.0.0/16 -m conntrack --ctstate NEW -j REJECT
    '';

    extraStopCommands = ''
      ${pkgs.iptables}/bin/iptables -D OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
      ${pkgs.iptables}/bin/iptables -D OUTPUT -d 10.0.0.0/8 -m conntrack --ctstate NEW -j REJECT || true
      ${pkgs.iptables}/bin/iptables -D OUTPUT -d 172.16.0.0/12 -m conntrack --ctstate NEW -j REJECT || true
      ${pkgs.iptables}/bin/iptables -D OUTPUT -d 192.168.0.0/16 -m conntrack --ctstate NEW -j REJECT || true
    '';
  };

  systemd.services.firefly-iii-data-importer-setup = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };

  services.firefly-iii-data-importer = {
    enable = true;
    enableNginx = true;
    virtualHost = "firefly-importer";

    settings = {
      FIREFLY_III_URL = fireflyUrl;
      FIREFLY_III_CLIENT_ID = "6";
      ENABLE_BANKING_APP_ID_FILE = config.sops.secrets."firefly/eb_app_id".path;
      ENABLE_BANKING_PRIVATE_KEY_FILE = config.sops.secrets."firefly/eb_key".path;
      TRUSTED_PROXIES = "**";
    };
  };

  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # EnableBanking production callbacks need HTTPS, so this VM is ready for a dedicated ingress URL.
  services.nginx.virtualHosts."firefly-importer".listen = lib.mkForce [
    {
      addr = "0.0.0.0";
      inherit (reg) port;
    }
  ];
}
