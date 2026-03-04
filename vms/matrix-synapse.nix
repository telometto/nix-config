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
    ../modules/services/matrix-synapse.nix
    inputs.sops-nix.nixosModules.sops
  ];

  # After first boot, get the VM's age key with:
  #   ssh admin@10.100.0.60 "sudo ssh-keygen -y -f /persist/ssh/ssh_host_ed25519_key" | ssh-to-age
  # Then add it to .sops.yaml and re-encrypt secrets
  sops = {
    defaultSopsFile = inputs.nix-secrets.secrets.secretsFile;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/persist/ssh/ssh_host_ed25519_key" ];
    # Run sops-install-secrets as a systemd service (after local-fs.target)
    # instead of activation script, since /persist isn't mounted during activation
    useSystemdActivation = true;

    secrets = {
      "matrix-synapse/registration_shared_secret" = {
        mode = "0440";
        owner = "matrix-synapse";
        group = "matrix-synapse";
      };
      "protonmail/smtp_token" = {
        mode = "0440";
        owner = "matrix-synapse";
        group = "matrix-synapse";
      };
    };
  };

  microvm = {
    hypervisor = "cloud-hypervisor";

    vsock.cid = 119;

    mem = 4096;
    vcpu = 4;

    volumes = [
      {
        mountPoint = "/var/lib/matrix-synapse";
        image = "matrix-synapse-state.img";
        size = 20480;
      }
      {
        mountPoint = "/var/lib/postgresql";
        image = "postgresql-state.img";
        size = 10240;
      }
      {
        mountPoint = "/persist";
        image = "persist.img";
        size = 64;
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = "vm-matrix";
        mac = "02:00:00:00:00:14";
      }
    ];

    shares = [
      {
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag = "ro-store";
        proto = "virtiofs";
      }
    ];
  };

  networking = {
    hostName = "matrix-synapse-vm";

    useDHCP = false;
    useNetworkd = true;

    firewall.enable = true;
  };

  systemd = {
    network.networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ "10.100.0.60/24" ];
        Gateway = "10.100.0.1";
        DNS = [ "1.1.1.1" ];
        DHCP = "no";
      };
    };

    tmpfiles.rules = [
      "d /persist/ssh 0700 root root -"
      "d /var/lib/matrix-synapse 0700 matrix-synapse matrix-synapse -"
      "d /var/lib/postgresql 0700 postgres postgres -"
    ];

    services = {
      matrix-synapse = {
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
      };

      matrix-synapse-secret = {
        description = "Generate Matrix Synapse shared secret config";
        before = [ "matrix-synapse.service" ];
        requiredBy = [ "matrix-synapse.service" ];
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "matrix-synapse";
          Group = "matrix-synapse";
          UMask = "0337";
          RuntimeDirectory = "matrix-synapse-secret";
          RuntimeDirectoryMode = "0750";
        };

        script = ''
          set -euo pipefail
          # Synapse does a shallow (top-level) merge of extra config files,
          # so the entire email block must be here — a partial block would
          # replace the main config's email dict and drop required keys.
          # --rawfile reads secrets directly from files, keeping them out
          # of /proc/<pid>/cmdline (unlike --arg which expands in argv).
          ${pkgs.jq}/bin/jq -n \
            --rawfile secret ${config.sops.secrets."matrix-synapse/registration_shared_secret".path} \
            --rawfile smtp ${config.sops.secrets."protonmail/smtp_token".path} \
            --arg notif_from "Matrix <matrix@${VARS.domains.public}>" \
            --arg smtp_user "matrix@${VARS.domains.public}" \
            '{
              registration_shared_secret: ($secret | rtrimstr("\n")),
              email: {
                smtp_host: "smtp.protonmail.ch",
                smtp_port: 587,
                smtp_user: $smtp_user,
                smtp_pass: ($smtp | rtrimstr("\n")),
                require_transport_security: true,
                notif_from: $notif_from,
                app_name: "Matrix",
                enable_notifs: false
              }
            }' \
            > /run/matrix-synapse-secret/shared-secret.yaml
        '';
      };
    };
  };

  sys.services.matrix-synapse = {
    enable = true;

    port = 8008;
    serverName = VARS.domains.public;
    openFirewall = false;

    database.createLocally = true;
    urlPreview.enable = true;

    extraConfigFiles = [
      "/run/matrix-synapse-secret/shared-secret.yaml"
    ];

    publicBaseUrl = "https://matrix.${VARS.domains.public}";

    reverseProxy.enable = false;

    settings = {
      # Let users browse other servers' public room directories
      allow_public_rooms_over_federation = true;

      # Suppress warning about trusting the default matrix.org key server
      suppress_key_server_warning = true;

      # Auto-purge cached remote media after 90 days to save disk
      media_retention.remote_media_lifetime = "90d";

      # Allow uploads up to 90 MB
      max_upload_size = "90M";

      # Disable presence (online/offline tracking) to reduce resource usage
      presence.enabled = false;

      # Disable Synapse's built-in well-known — it generates m.server from
      # server_name (mydomain.no:443) instead of the delegated matrix.mydomain.no.
      # Nginx in front of Synapse serves the correct responses instead.
      serve_server_wellknown = false;

      # Auto-join new users into a welcome room (create this room first)
      # auto_join_rooms = [ "#welcome:${VARS.domains.public}" ];

      # --- Access control ---

      # Token-gated registration — set to false when done inviting users
      enable_registration = true;

      # Disable guest access entirely
      allow_guest_access = false;

      # Require authentication to browse the public room directory
      allow_public_rooms_without_auth = false;

      # Require auth for profile lookups
      require_auth_for_profile_requests = true;

      # Only show profiles of users who share a room with the requester
      limit_profile_requests_to_users_who_share_rooms = true;

      # Users must present a valid token to register
      registration_requires_token = true;

      # Require verified email during sign-up
      registrations_require_3pid = [ "email" ];

      # Allow users to add/remove validated 3PIDs (email/phone) on account
      enable_3pid_changes = true;

      # Email/SMTP config (including smtp_pass) is injected at runtime
      # via /run/matrix-synapse-secret/shared-secret.yaml to keep the
      # SMTP token out of the world-readable /nix/store. Synapse does a
      # shallow merge on top-level keys, so the entire email block must
      # live in the extra config file.

      # Don't reveal whether a 3PID (email/phone) is registered
      request_token_inhibit_3pid_errors = true;

      # Admin contact shown to users on resource-limit errors
      admin_contact = "mailto:matrix@${VARS.domains.public}";

      # --- Federation hardening ---

      # Require TLS 1.2+ for outbound federation connections
      federation_client_minimum_tls_version = "1.2";

      # Don't leak device display names over federation
      allow_device_name_lookup_over_federation = false;

      # --- Rate limiting ---

      rc_message = {
        per_second = 0.5;
        burst_count = 15;
      };

      rc_registration = {
        per_second = 0.05;
        burst_count = 3;
      };

      rc_login = {
        address = {
          per_second = 0.1;
          burst_count = 5;
        };
        account = {
          per_second = 0.1;
          burst_count = 5;
        };
        failed_attempts = {
          per_second = 0.05;
          burst_count = 3;
        };
      };

      rc_joins = {
        local = {
          per_second = 0.2;
          burst_count = 10;
        };
        remote = {
          per_second = 0.03;
          burst_count = 5;
        };
      };

      # --- Session management ---

      # Absolute session lifetime (30 days)
      session_lifetime = "720h";

      # Access tokens without refresh support expire after 7 days
      nonrefreshable_access_token_lifetime = "168h";

      # Purge devices with no activity after 180 days
      delete_stale_devices_after = "180d";

      # Auto-remove rooms from local state when a user leaves
      forget_rooms_on_leave = true;

      # --- Password policy ---

      password_config = {
        enabled = true;
        policy = {
          enabled = true;
          minimum_length = 12;
          require_digit = true;
          require_symbol = true;
          require_lowercase = true;
          require_uppercase = true;
        };
      };

      # --- Performance ---

      # Tuned for a small deployment (2-10 users)
      caches.global_factor = 1.0;
    };
  };

  # Nginx sits in front of Synapse on the externally-exposed port (11060).
  # It serves correct /.well-known/matrix/* responses for federation and
  # client auto-discovery, and proxies everything else to Synapse (8008).
  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # Avoid warning about proxy_headers_hash with recommended settings
    appendHttpConfig = ''
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
    '';

    virtualHosts."matrix" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 11060;
        }
      ];

      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:8008";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 600s;
            client_max_body_size 90M;
          '';
        };

        "= /.well-known/matrix/server" = {
          return = "200 '{\"m.server\":\"matrix.${VARS.domains.public}:443\"}'";
          extraConfig = ''
            default_type application/json;
            add_header Access-Control-Allow-Origin *;
          '';
        };

        "= /.well-known/matrix/client" = {
          return = "200 '{\"m.homeserver\":{\"base_url\":\"https://matrix.${VARS.domains.public}\"}}'";
          extraConfig = ''
            default_type application/json;
            add_header Access-Control-Allow-Origin *;
          '';
        };
      };
    };
  };

  # Nginx takes over the external port; Synapse listens on 8008 (localhost only)
  networking.firewall.allowedTCPPorts = [ 11060 ];

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

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      VARS.users.zeno.sshPubKey
    ];
  };

  # security.sudo.wheelNeedsPassword = lib.mkForce false;

  system.stateVersion = "24.11";
}
