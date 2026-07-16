{
  config,
  inputs,
  VARS,
  ...
}:
let
  reg = (import ./vm-registry.nix)."pocket-id";
  dataDir = "/var/lib/pocket-id";
  blizzardSource = "${reg.gateway}/32";
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
            mountPoint = dataDir;
            image = "pocket-id-state.img";
            size = 2048;
          }
        ];
      }
    ))
  ];

  # The VM's persistent SSH host key is its SOPS age identity. On first boot,
  # add that recipient and pocket-id/encryption_key to the private nix-secrets
  # flake before expecting the service to start successfully.
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets."pocket-id/encryption_key" = {
      mode = "0400";
      owner = "pocket-id";
      group = "pocket-id";
      restartUnits = [ "pocket-id.service" ];
    };
  };

  # Pocket ID trusts Cloudflare's client-IP header, so its backend must only be
  # reachable through Blizzard's Traefik instance. Restrict administrative SSH
  # to Blizzard as well, retaining explicit guest-level boundaries in addition
  # to the host's cross-bridge forwarding policy.
  networking = {
    nftables.enable = true;
    firewall.extraInputRules = ''
      ip saddr ${blizzardSource} ip daddr ${reg.ip} tcp dport 22 accept comment "Pocket ID SSH from Blizzard only"
      ip saddr ${blizzardSource} ip daddr ${reg.ip} tcp dport ${toString reg.port} accept comment "Pocket ID via Blizzard Traefik only"
    '';
  };

  services.openssh.openFirewall = false;

  services.pocket-id = {
    enable = true;
    inherit dataDir;

    credentials.ENCRYPTION_KEY = config.sops.secrets."pocket-id/encryption_key".path;

    settings = {
      APP_URL = "https://id.${VARS.domains.public}";
      HOST = "0.0.0.0";
      PORT = reg.port;

      DB_CONNECTION_STRING = "${dataDir}/pocket-id.db";
      FILE_BACKEND = "filesystem";
      UPLOAD_PATH = "${dataDir}/uploads";

      TRUSTED_PLATFORM = "CF-Connecting-IP";
      UI_CONFIG_DISABLED = true;
      ALLOW_USER_SIGNUPS = "withToken";
      ANALYTICS_DISABLED = true;
      VERSION_CHECK_DISABLED = true;
    };
  };

  # Keep the exact packaged CLI available for health checks and the documented
  # export/import recovery workflow.
  environment.systemPackages = [ config.services.pocket-id.package ];

  systemd.services.pocket-id = {
    after = [
      "network-online.target"
      "sops-install-secrets.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "sops-install-secrets.service" ];
  };
}
