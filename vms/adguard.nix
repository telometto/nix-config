{
  lib,
  config,
  inputs,
  VARS,
  ...
}:
let
  reg = (import ./vm-registry.nix).adguard;
in
{
  imports = [
    ./base.nix
    ../modules/services/adguardhome.nix
    ../modules/services/resolved.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            # NOTE: NixOS adguardhome uses DynamicUser=true, requiring /var/lib/private/
            mountPoint = "/var/lib/private/AdGuardHome";
            image = "adguard-state.img";
            size = 10240;
          }
        ];
      }
    ))
  ];

  # SOPS configuration for this MicroVM
  # After first boot, derive the VM's age public key without copying the private key:
  #   ssh admin@10.100.0.10 "sudo ssh-keygen -y -f /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add the resulting age public key to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    useSystemdActivation = true;

    secrets = {
      "adguard/password_hash" = {
        mode = "0400";
        owner = "root";
      };

      "adguard/fullchain" = {
        mode = "0444";
      };

      "adguard/privkey" = {
        mode = "0400";
      };
    };
  };

  networking.firewall = {
    # DNS and encrypted DNS ports
    # Web UI port (11016) is handled by openFirewall = true
    allowedTCPPorts = [
      53 # DNS over TCP
      80 # HTTP (for Cloudflare tunnel)
      443 # DoH (DNS over HTTPS)
      853 # DoT (DNS over TLS)
    ];

    allowedUDPPorts = [
      53 # DNS
    ];
  };

  # Enable AdGuard Home
  sys.services.adguardhome = {
    enable = true;
    port = reg.port;
    mutableSettings = true;
    openFirewall = true;

    # Workaround for AdGuard Home v0.107.71 dual-stack DoT bind issue
    # (https://github.com/AdguardTeam/AdGuardHome/discussions/7395)
    settings.dns.bind_hosts = lib.mkForce [ reg.ip ];
  };
}
