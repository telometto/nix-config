{
  lib,
  config,
  pkgs,
  inputs,
  VARS,
  ...
}:
let
  reg = (import ./vm-registry.nix)."matrix-synapse";
in
{
  imports = [
    ./base.nix
    ../modules/services/matrix-synapse.nix
    ../modules/services/matrix-authentication-service.nix
    inputs.sops-nix.nixosModules.sops
    (import ./mkMicrovmConfig.nix (
      reg
      // {
        volumes = [
          {
            mountPoint = "/var/lib/matrix-synapse";
            image = "matrix-synapse-state.img";
            size = 20480;
          }
          {
            mountPoint = "/var/lib/postgresql";
            image = "postgresql-state.img";
            size = 102400;
          }
          {
            mountPoint = "/var/lib/mas";
            image = "mas-state.img";
            size = 1024;
          }
        ];
      }
    ))
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
        owner = "root";
        group = "matrix-shared";
      };

      # --- MAS secrets ---
      # Generate once with: mas-cli config generate
      # Then extract and add to nix-secrets YAML.
      "matrix-authentication-service/encryption_key" = {
        mode = "0440";
        owner = "mas";
        group = "mas";
      };
      "matrix-authentication-service/signing_key_rsa" = {
        mode = "0440";
        owner = "mas";
        group = "mas";
      };
      "matrix-authentication-service/signing_key_ec_p256" = {
        mode = "0440";
        owner = "mas";
        group = "mas";
      };
      "matrix-authentication-service/signing_key_ec_p384" = {
        mode = "0440";
        owner = "mas";
        group = "mas";
      };
      "matrix-authentication-service/signing_key_ec_secp256k1" = {
        mode = "0440";
        owner = "mas";
        group = "mas";
      };
      # Shared secret for MAS ↔ Synapse admin API calls
      "matrix-authentication-service/synapse_secret" = {
        mode = "0440";
        owner = "root";
        group = "matrix-shared";
      };
      # OIDC client secret — same value in MAS clients[] and Synapse msc3861
      "matrix-authentication-service/client_secret" = {
        mode = "0440";
        owner = "root";
        group = "matrix-shared";
      };
    };
  };

  # Nginx takes over the external port; Synapse listens on 8008 (localhost only)
  networking.firewall.allowedTCPPorts = [ reg.port ];

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/matrix-synapse 0700 matrix-synapse matrix-synapse -"
      "d /var/lib/postgresql 0700 postgres postgres -"
      "d /var/lib/mas 0700 mas mas -"
    ];

    services = {
      matrix-synapse = {
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
      };

      # Assembles Synapse's runtime config with secrets + MSC3861 auth
      # delegation block. Shallow-merged by Synapse on top of the main config.
      matrix-synapse-secret = {
        description = "Generate Matrix Synapse secret + auth delegation config";
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

        script =
          let
            authCfg = config.sys.services.matrix-synapse.authDelegation;
            masArgs = lib.escapeShellArgs (
              lib.optionals authCfg.enable [
                "--rawfile"
                "mas_secret"
                config.sops.secrets."matrix-authentication-service/synapse_secret".path
                "--arg"
                "mas_endpoint"
                authCfg.masEndpoint
              ]
            );
            masJqExpr = lib.optionalString authCfg.enable ''
              * {
                matrix_authentication_service: {
                  enabled: true,
                  endpoint: $mas_endpoint,
                  secret: ($mas_secret | rtrimstr("\n"))
                }
              }
            '';
          in
          ''
            set -euo pipefail
            ${pkgs.jq}/bin/jq -n \
              --rawfile secret ${config.sops.secrets."matrix-synapse/registration_shared_secret".path} \
              --rawfile smtp ${config.sops.secrets."protonmail/smtp_token".path} \
              --arg notif_from "Matrix <matrix@${VARS.domains.public}>" \
              --arg smtp_user "matrix@${VARS.domains.public}" \
              ${masArgs} \
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
              }${masJqExpr}' \
              > /run/matrix-synapse-secret/shared-secret.yaml
          '';
      };

      # Assembles MAS runtime config by merging the Nix-generated base
      # config with decrypted secrets (encryption key, signing keys,
      # Synapse shared secret, OIDC client secret, SMTP password).
      mas-secret = {
        description = "Generate MAS runtime config with secrets";
        before = [ "matrix-authentication-service.service" ];
        requiredBy = [ "matrix-authentication-service.service" ];
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "mas";
          Group = "mas";
          UMask = "0337";
          RuntimeDirectory = "mas-secret";
          RuntimeDirectoryMode = "0750";
        };

        script = ''
          set -euo pipefail
          ${pkgs.jq}/bin/jq -n \
            --slurpfile base /etc/matrix-authentication-service/config.json \
            --rawfile encryption_key ${
              config.sops.secrets."matrix-authentication-service/encryption_key".path
            } \
            --rawfile rsa_key ${config.sops.secrets."matrix-authentication-service/signing_key_rsa".path} \
            --rawfile ec_p256 ${
              config.sops.secrets."matrix-authentication-service/signing_key_ec_p256".path
            } \
            --rawfile ec_p384 ${
              config.sops.secrets."matrix-authentication-service/signing_key_ec_p384".path
            } \
            --rawfile ec_k256 ${
              config.sops.secrets."matrix-authentication-service/signing_key_ec_secp256k1".path
            } \
            --rawfile synapse_secret ${
              config.sops.secrets."matrix-authentication-service/synapse_secret".path
            } \
            --rawfile client_secret ${
              config.sops.secrets."matrix-authentication-service/client_secret".path
            } \
            --rawfile smtp_pass ${config.sops.secrets."protonmail/smtp_token".path} \
            --arg client_id "${config.sys.services.matrix-authentication-service.clientId}" \
            --arg client_auth_method "${config.sys.services.matrix-synapse.authDelegation.clientAuthMethod}" \
            '$base[0] * {
              secrets: {
                encryption: ($encryption_key | rtrimstr("\n")),
                keys: [
                  {key: $rsa_key},
                  {key: $ec_p256},
                  {key: $ec_p384},
                  {key: $ec_k256}
                ]
              },
              matrix: ($base[0].matrix * {
                secret: ($synapse_secret | rtrimstr("\n"))
              }),
              clients: [{
                client_id: $client_id,
                client_auth_method: $client_auth_method,
                client_secret: ($client_secret | rtrimstr("\n"))
              }],
              email: ($base[0].email * {
                password: ($smtp_pass | rtrimstr("\n"))
              })
            }' \
            > /run/mas-secret/config.json
        '';
      };

      matrix-authentication-service = {
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
      };
    };
  };

  # --- Matrix Authentication Service (MAS) ---
  # MAS handles all auth flows (login, registration, OIDC) so
  # Element X and other MSC3861/OIDC-native clients can work.
  sys = {
    services = {
      matrix-authentication-service = {
        enable = true;

        port = 8081;
        healthPort = 8082;

        publicBaseUrl = "https://matrix.${VARS.domains.public}/";
        issuer = "https://matrix.${VARS.domains.public}/";

        database.createLocally = true;

        email = {
          from = ''"Matrix" <matrix@${VARS.domains.public}>'';
          replyTo = ''"Matrix" <matrix@${VARS.domains.public}>'';
          transport = "smtp";
          mode = "starttls";
          hostname = "smtp.protonmail.ch";
          smtpPort = 587;
          username = "matrix@${VARS.domains.public}";
          # password injected at runtime by mas-secret service
        };

        passwords = {
          enabled = true;
          minimumComplexity = 3;
        };

        matrix = {
          homeserver = "${VARS.domains.public}";
          endpoint = "http://localhost:8008/";
        };

        clientId = "0000000000000000000SYNAPSE";

        runtimeConfigFile = "/run/mas-secret/config.json";

        # Enable registration and account management in MAS.
        # Without this, MAS only advertises "login" in prompt_values_supported
        # and all registration attempts redirect to login.
        settings = {
          # Include bcrypt as scheme v1 so migrated Synapse password hashes
          # (which are bcrypt) keep working after syn2mas import.  New
          # registrations and re-logins will upgrade hashes to argon2id (v2).
          passwords.schemes = [
            {
              version = 1;
              algorithm = "bcrypt";
              unicode_normalization = true;
              # If Synapse had a password pepper, set it here:
              # secret = "your-synapse-pepper";
            }
            {
              version = 2;
              algorithm = "argon2id";
            }
          ];
          account = {
            password_registration_enabled = true;
            email_change_allowed = true;
            displayname_change_allowed = true;
            password_change_allowed = true;
          };
          # Allow dynamic client registration so Element X (and other
          # OIDC-native clients) can register themselves as OAuth clients.
          # Without this, MAS rejects the POST to /oauth2/registration
          # and Element X reports "can't reach this homeserver".
          policy.data.client_registration = {
            allow_host_mismatch = true;
            allow_insecure_uris = false;
          };
        };
      };

      # --- Synapse ---
      matrix-synapse = {
        enable = true;

        port = 8008;
        serverName = VARS.domains.public;
        openFirewall = false;

        database.createLocally = true;
        urlPreview.enable = true;
        autoCompressor.enable = true;

        extraConfigFiles = [
          "/run/matrix-synapse-secret/shared-secret.yaml"
        ];

        publicBaseUrl = "https://matrix.${VARS.domains.public}";

        reverseProxy.enable = false;

        # Delegate core login and registration flows to MAS; other auth-related
        # endpoints (for example password changes) are still handled by Synapse.
        authDelegation = {
          enable = true;
          issuer = "https://matrix.${VARS.domains.public}/";
          clientId = "0000000000000000000SYNAPSE";
          accountManagementUrl = "https://matrix.${VARS.domains.public}/account/";
          masEndpoint = "http://localhost:${toString config.sys.services.matrix-authentication-service.port}/";
        };

        settings = {
          # Let users browse other servers' public room directories
          allow_public_rooms_over_federation = true;

          # QR code device linking (MSC4108) — exposes /_synapse/client/rendezvous
          # and advertises support in /versions for Element's "Link new device" flow
          experimental_features.msc4108_enabled = true;

          # Suppress warning about trusting the default matrix.org key server
          suppress_key_server_warning = true;

          # Auto-purge cached remote media after 90 days to save disk
          media_retention.remote_media_lifetime = "90d";

          # Allow uploads up to 90 MB
          max_upload_size = "90M";

          # Disable presence (online/offline tracking) to reduce resource usage
          presence.enabled = false;

          # Disable Synapse's built-in well-known — Nginx handles it
          serve_server_wellknown = false;

          # --- Access control ---
          # Registration and password policy are now managed by MAS.
          # These Synapse-side settings remain for non-auth access control.

          allow_guest_access = false;
          allow_public_rooms_without_auth = false;
          require_auth_for_profile_requests = true;
          limit_profile_requests_to_users_who_share_rooms = true;

          # Email/SMTP config (including smtp_pass) is injected at runtime
          # via /run/matrix-synapse-secret/shared-secret.yaml.

          admin_contact = "mailto:matrix@${VARS.domains.public}";

          # --- Federation hardening ---

          federation_client_minimum_tls_version = "1.2";
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

          delete_stale_devices_after = "180d";
          forget_rooms_on_leave = true;

          # --- Performance ---

          caches.global_factor = 1.0;
        };
      };
    };
  };

  # Nginx sits in front of Synapse (8008) and MAS (8081) on port 11060.
  # Routes auth-related paths to MAS, everything else to Synapse.
  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    appendHttpConfig = ''
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
    '';

    virtualHosts."matrix" = {
      listen = [
        {
          addr = "0.0.0.0";
          inherit (reg) port;
        }
      ];

      locations = {
        # --- MAS compatibility layer ---
        # Route Synapse login/logout/refresh to MAS so legacy and OIDC
        # clients both work through the same endpoints.
        # Anchored with (/|$) so sub-paths like /login/sso/redirect reach
        # MAS for SSO/compat login flows (e.g. mobile Element), without
        # overmatching paths like /loginXYZ.
        "~ ^/_matrix/client/(r0|v1|v3)/login(/|$)" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        "~ ^/_matrix/client/(r0|v1|v3)/logout(/all)?$" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        "~ ^/_matrix/client/(r0|v1|v3)/refresh$" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };

        # --- MAS OIDC / UI paths ---
        "/.well-known/openid-configuration" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        "/oauth2/" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        "/authorize" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        "/register" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        "/account/" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        "/assets/" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        # MAS JWKS endpoint for token verification
        "/.well-known/jwks.json" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        # MAS GraphQL admin API
        "/graphql" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        # MAS human-facing pages (login, logout, consent, recovery, etc.)
        "~ ^/(login|logout|consent|recover|change-password|link|complete-compat-sso)" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };
        "/upstream/" = {
          proxyPass = "http://127.0.0.1:8081";
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
          '';
        };

        # --- Synapse (everything else) ---
        "/" = {
          proxyPass = "http://127.0.0.1:8008";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto https;
            proxy_read_timeout 600s;
            client_max_body_size 90M;
          '';
        };

        # --- Well-known ---
        "= /.well-known/matrix/server" = {
          return = "200 '{\"m.server\":\"matrix.${VARS.domains.public}:443\"}'";
          extraConfig = ''
            default_type application/json;
            add_header Access-Control-Allow-Origin *;
          '';
        };

        # Includes m.authentication (stable) and org.matrix.msc2965.authentication
        # (unstable) so OIDC-native clients (Element X) discover MAS.
        "= /.well-known/matrix/client" = {
          return = "200 '{\"m.homeserver\":{\"base_url\":\"https://matrix.${VARS.domains.public}\"},\"m.authentication\":{\"issuer\":\"https://matrix.${VARS.domains.public}/\",\"account\":\"https://matrix.${VARS.domains.public}/account/\"},\"org.matrix.msc2965.authentication\":{\"issuer\":\"https://matrix.${VARS.domains.public}/\",\"account\":\"https://matrix.${VARS.domains.public}/account/\"}}'";
          extraConfig = ''
            default_type application/json;
            add_header Access-Control-Allow-Origin *;
          '';
        };

        # MSC1929: admin contact info for homeserver discovery
        "= /.well-known/matrix/support" = {
          return = "200 '{\"contacts\":[{\"role\":\"admin\",\"email_address\":\"matrix@${VARS.domains.public}\"}]}'";
          extraConfig = ''
            default_type application/json;
            add_header Access-Control-Allow-Origin *;
          '';
        };
      };
    };
  };

  users = {
    groups.matrix-shared = { };
    users = {
      mas.extraGroups = [ "matrix-shared" ];
      matrix-synapse.extraGroups = [ "matrix-shared" ];
    };
  };
}
