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
    ../modules/services/adguardhome.nix
    ../modules/services/resolved.nix
    inputs.sops-nix.nixosModules.sops
  ];

  # SOPS configuration for this MicroVM
  # After first boot, get the VM's age key with:
  #   ssh admin@10.100.0.10 "sudo cat /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add it to your .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
  };

  sops.secrets."adguard/password_hash" = {
    mode = "0400";
    owner = "root";
  };

  sops.secrets."adguard/fullchain" = {
    mode = "0444";
  };

  sops.secrets."adguard/privkey" = {
    mode = "0400";
  };

  networking.hostName = "adguard-vm";

  # MicroVM-specific configuration
  microvm = {
    hypervisor = "cloud-hypervisor";

    # Enable vsock for systemd-notify (required by cloud-hypervisor)
    # CID must be unique per VM (3+ range, 0-2 are reserved)
    vsock.cid = 100;

    # 3GiB RAM - AdGuard Home needs ~350MB+ with filters loaded
    mem = 3072;
    vcpu = 1;

    # Persistent state volume for AdGuard configuration and data
    # Path is relative to host's microvm.stateDir/<vm-name>/
    # Configure stateDir on the HOST via sys.virtualisation.microvm.stateDir
    # NOTE: NixOS adguardhome uses DynamicUser=true, requiring /var/lib/private/
    volumes = [
      {
        mountPoint = "/var/lib/private/AdGuardHome";
        image = "adguard-state.img";
        size = 5120; # 5GiB for logs and config
      }
      {
        mountPoint = "/persist";
        image = "persist.img";
        size = 64; # 64MiB for SSH keys and other persistent state
      }
    ];

    # Network interface - connects to host bridge
    interfaces = [
      {
        type = "tap";
        id = "vm-adguard";
        mac = "02:00:00:00:00:01";
      }
    ];

    # Share host's nix store (read-only) for smaller image size
    shares = [
      {
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag = "ro-store";
        proto = "virtiofs";
      }
    ];
  };

  # Static IP on the MicroVM network (using systemd-networkd)
  networking = {
    useDHCP = false;
    useNetworkd = true;

    firewall = {
      enable = true;
      # DNS and potential future HTTPS/DoH ports
      # Web UI port (11016) is handled by openFirewall = true
      allowedTCPPorts = [
        53 # DNS over TCP
        80 # HTTP (for future use or Cloudflare tunnel)
        443 # HTTPS/DoH (if TLS enabled later)
      ];
      allowedUDPPorts = [
        53 # DNS
      ];
    };
  };

  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [ "10.100.0.10/24" ];
      Gateway = "10.100.0.1";
      DNS = [ "1.1.1.1" ];
      DHCP = "no";
    };
  };

  # Enable AdGuard Home
  sys.services.adguardhome = {
    enable = true;
    port = 11016;
    mutableSettings = false;
    openFirewall = true;

    # Username only - password injected at runtime via SOPS
    settings.users = [
      {
        name = VARS.svc.agh.user;
        password = "PLACEHOLDER_WILL_BE_REPLACED";
      }
    ];

    # Workaround for AdGuard Home v0.107.71 dual-stack DoT bind issue
    # (https://github.com/AdguardTeam/AdGuardHome/discussions/7395)
    settings.dns.bind_hosts = lib.mkForce [ "10.100.0.10" ];

    # TLS certificates from SOPS (using file paths instead of inline content)
    settings.tls = {
      server_name = "adguard.${VARS.domains.public}";
      certificate_chain = "";
      private_key = "";
      certificate_path = config.sops.secrets."adguard/fullchain".path;
      private_key_path = config.sops.secrets."adguard/privkey".path;
    };
  };

  # SSH host keys on persistent storage for stable identity across rebuilds
  systemd.tmpfiles.rules = [
    "d /persist/ssh 0700 root root -"
  ];

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

  # Inject password hash from SOPS at runtime (before AdGuard starts)
  systemd.services.adguardhome-inject-secrets = {
    description = "Inject AdGuard Home password from SOPS";
    before = [ "adguardhome.service" ];
    requiredBy = [ "adguardhome.service" ];
    after = [ "sops-nix.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      CONFIG="/var/lib/private/AdGuardHome/AdGuardHome.yaml"
      [ -f "$CONFIG" ] || exit 0

      SECRET_PATH="${config.sops.secrets."adguard/password_hash".path}"
      if ! HASH=$(cat "$SECRET_PATH" 2>/dev/null); then
        echo "Failed to read password hash from $SECRET_PATH" >&2
        exit 1
      fi

      if [ -z "$HASH" ]; then
        echo "Password hash is empty" >&2
        exit 1
      fi

      export HASH
      ${pkgs.yq-go}/bin/yq -i '.users[0].password = strenv(HASH)' "$CONFIG"
    '';
  };

  # Create admin user for SSH management
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      VARS.users.zeno.sshPubKey
    ];
  };

  # Allow wheel group sudo without password inside this MicroVM
  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  system.stateVersion = "24.11";
}
