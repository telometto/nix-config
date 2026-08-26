{
  lib,
  config,
  pkgs,
  inputs,
  VARS,
  consts,
  ...
}:
let
  reg = (import ./vm-registry.nix { inherit consts; })."matrix-synapse";
  networkDefaults = import ./microvm-network-defaults.nix;
  matrixGateway = reg.gateway or networkDefaults.defaultGateway;
  traefikLib = import ../lib/traefik.nix { inherit lib; };
  inherit (traefikLib) matrixRoutes;
  configuredMasRuntimeConfigFile =
    config.sys.services.matrix-authentication-service.runtimeConfigFile;
  masRuntimeConfigFile =
    if configuredMasRuntimeConfigFile != null then
      configuredMasRuntimeConfigFile
    else
      "/run/mas-secret/config.json";
  masRuntimeConfigDirectory = builtins.dirOf masRuntimeConfigFile;
  masRuntimeDirectory = lib.removePrefix "/run/" masRuntimeConfigDirectory;
  matrixWhatsappEnabled = config.services.mautrix-whatsapp.enable;
  matrixWhatsappDataDir = "/var/lib/mautrix-whatsapp";
  matrixWhatsappRegistrationGroup = "matrix-whatsapp-registration";
  matrixWhatsappRegistrationDirectory = "/run/matrix-whatsapp-registration";
  matrixWhatsappSettingsFile = "${matrixWhatsappDataDir}/config.yaml";
  matrixWhatsappSettingsRenderedFile = "${matrixWhatsappSettingsFile}.rendered";
  matrixWhatsappSettingsTempFile = "${matrixWhatsappSettingsFile}.tmp";
  matrixWhatsappRegistrationFile = "${matrixWhatsappRegistrationDirectory}/whatsapp-registration.yaml";
  matrixWhatsappRegistrationTempFile = "${matrixWhatsappRegistrationFile}.tmp";
  matrixWhatsappEnvironmentFile = config.sops.templates."matrix-whatsapp-environment".path;
  matrixWhatsappDatabasePasswordPath = config.sops.secrets."matrix-whatsapp/database_password".path;
  matrixWhatsappRestartUnits = [
    "mautrix-whatsapp-db-init.service"
    "mautrix-whatsapp-registration.service"
    "matrix-synapse.service"
    "mautrix-whatsapp.service"
  ];
  matrixWhatsappSettingsUnsubstituted =
    pkgs.formats.json { }.generate "mautrix-whatsapp-config-unsubstituted.json"
      config.services.mautrix-whatsapp.settings;
  matrixWhatsappAdmin = "@${VARS.users.zeno.user}:${VARS.domains.public}";
  secretGeneratorHardening = {
    AmbientCapabilities = "";
    CapabilityBoundingSet = "";
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectSystem = "strict";
    RemoveIPC = true;
    RestrictAddressFamilies = [ "AF_UNIX" ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
  };
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
        ]
        ++ lib.optionals matrixWhatsappEnabled [
          {
            mountPoint = "/var/lib/mautrix-whatsapp";
            image = "mautrix-whatsapp-state.img";
            size = 10240;
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
      # Dedicated Proton SMTP token for MAS account recovery mail.
      "matrix-authentication-service/smtp_token" = {
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
      # OIDC client secret - same value in MAS clients[] and Synapse msc3861
      "matrix-authentication-service/client_secret" = {
        mode = "0440";
        owner = "root";
        group = "matrix-shared";
      };
      # Mautrix-WhatsApp appservice and bridge secrets. Values are consumed
      # through the SOPS-rendered environment file below and never enter the
      # Nix-generated bridge configuration.
    }
    // lib.optionalAttrs matrixWhatsappEnabled {
      "matrix-whatsapp/appservice_as_token" = {
        mode = "0440";
        owner = "root";
        group = "mautrix-whatsapp";
        restartUnits = matrixWhatsappRestartUnits;
      };
      "matrix-whatsapp/appservice_hs_token" = {
        mode = "0440";
        owner = "root";
        group = "mautrix-whatsapp";
        restartUnits = matrixWhatsappRestartUnits;
      };
      "matrix-whatsapp/provisioning_shared_secret" = {
        mode = "0440";
        owner = "root";
        group = "mautrix-whatsapp";
        restartUnits = matrixWhatsappRestartUnits;
      };
      "matrix-whatsapp/encryption_pickle_key" = {
        mode = "0440";
        owner = "root";
        group = "mautrix-whatsapp";
        restartUnits = matrixWhatsappRestartUnits;
      };
      "matrix-whatsapp/public_media_signing_key" = {
        mode = "0440";
        owner = "root";
        group = "mautrix-whatsapp";
        restartUnits = matrixWhatsappRestartUnits;
      };
      "matrix-whatsapp/direct_media_server_key" = {
        mode = "0440";
        owner = "root";
        group = "mautrix-whatsapp";
        restartUnits = matrixWhatsappRestartUnits;
      };
      # The bridge connects to PostgreSQL over loopback with password
      # authentication so its upstream PrivateUsers sandbox can remain on.
      # Only postgres and the rendered bridge environment need this value.
      "matrix-whatsapp/database_password" = {
        mode = "0440";
        owner = "root";
        group = "postgres";
        restartUnits = matrixWhatsappRestartUnits;
      };
    };

    templates = lib.optionalAttrs matrixWhatsappEnabled {
      "matrix-whatsapp-environment" = {
        owner = "mautrix-whatsapp";
        group = "mautrix-whatsapp";
        mode = "0400";
        content = ''
          MAUTRIX_WHATSAPP_APPSERVICE_AS_TOKEN=${
            config.sops.placeholder."matrix-whatsapp/appservice_as_token"
          }
          MAUTRIX_WHATSAPP_APPSERVICE_HS_TOKEN=${
            config.sops.placeholder."matrix-whatsapp/appservice_hs_token"
          }
          MAUTRIX_WHATSAPP_PROVISIONING_SHARED_SECRET=${
            config.sops.placeholder."matrix-whatsapp/provisioning_shared_secret"
          }
          MAUTRIX_WHATSAPP_ENCRYPTION_PICKLE_KEY=${
            config.sops.placeholder."matrix-whatsapp/encryption_pickle_key"
          }
          MAUTRIX_WHATSAPP_PUBLIC_MEDIA_SIGNING_KEY=${
            config.sops.placeholder."matrix-whatsapp/public_media_signing_key"
          }
          MAUTRIX_WHATSAPP_DIRECT_MEDIA_SERVER_KEY=${
            config.sops.placeholder."matrix-whatsapp/direct_media_server_key"
          }
          PGPASSWORD=${config.sops.placeholder."matrix-whatsapp/database_password"}
        '';
      };
    };
  };

  assertions = [
    {
      assertion = lib.hasPrefix "/run/" masRuntimeConfigDirectory && masRuntimeConfigDirectory != "/run";
      message = "The Matrix VM MAS runtimeConfigFile must be below /run and include a parent directory";
    }
  ]
  ++ lib.optionals matrixWhatsappEnabled [
    {
      assertion = config.services.mautrix-whatsapp.settings.appservice.hostname == "127.0.0.1";
      message = "Mautrix-WhatsApp must bind its appservice listener to the Matrix VM loopback address";
    }
    {
      assertion = config.services.mautrix-whatsapp.settings.appservice.port == 29318;
      message = "Mautrix-WhatsApp must use the reserved loopback appservice port 29318";
    }
    {
      assertion = !(config.services.mautrix-whatsapp.settings.appservice ? public_address);
      message = "Mautrix-WhatsApp must not publish an appservice public_address";
    }
  ];

  # Nginx is the only guest-network listener. Accept its traffic only from
  # Blizzard's MicroVM gateway; all other sources fall through to the default
  # firewall refusal path.
  networking.firewall = {
    allowedTCPPorts = [ ];
    extraCommands = ''
      ${pkgs.iptables}/bin/iptables -A nixos-fw -i ${networkDefaults.guestInterface} -p tcp --dport ${toString reg.port} -s ${matrixGateway} -j nixos-fw-accept
    '';
  };

  # The locked nixpkgs module normally generates the registration file in the
  # bridge service's preStart. Synapse needs that file before its own service
  # starts, so this VM-owned gate owns that preparation instead.
  services.mautrix-whatsapp = {
    # Keep the integration opt-in until private SOPS values, backup evidence,
    # and interactive-login acceptance have been completed.
    enable = lib.mkDefault false;
    registerToSynapse = false;
    environmentFile = lib.mkIf matrixWhatsappEnabled matrixWhatsappEnvironmentFile;
    serviceDependencies = lib.mkIf matrixWhatsappEnabled [
      "matrix-synapse.service"
      "mautrix-whatsapp-db-init.service"
      "mautrix-whatsapp-registration.service"
    ];
    settings = {
      homeserver = {
        address = "http://127.0.0.1:8008";
        domain = VARS.domains.public;
      };
      appservice = {
        address = "http://127.0.0.1:29318";
        hostname = "127.0.0.1";
        port = 29318;
        as_token = "$MAUTRIX_WHATSAPP_APPSERVICE_AS_TOKEN";
        hs_token = "$MAUTRIX_WHATSAPP_APPSERVICE_HS_TOKEN";
      };
      bridge = {
        # Relay mode is deliberately disabled. Only the named Matrix operator
        # is granted admin access before the first interactive login.
        relay.enabled = false;
        # Keep portal rooms on this homeserver until federation of bridged
        # history has a separate privacy review.
        federate_rooms = false;
        permissions = {
          "*" = "relay";
          "${matrixWhatsappAdmin}" = "admin";
        };
      };
      database = {
        type = "postgres";
        uri = "postgresql://mautrix-whatsapp@127.0.0.1/mautrix-whatsapp?sslmode=disable";
      };
      encryption = {
        allow = true;
        default = true;
        require = true;
        pickle_key = "$MAUTRIX_WHATSAPP_ENCRYPTION_PICKLE_KEY";
      };
      public_media.signing_key = "$MAUTRIX_WHATSAPP_PUBLIC_MEDIA_SIGNING_KEY";
      direct_media.server_key = "$MAUTRIX_WHATSAPP_DIRECT_MEDIA_SERVER_KEY";
      network = {
        displayname_template = "{{or .BusinessName .PushName .Phone}} (WA)";
        history_sync.request_full_sync = false;
        identity_change_notices = true;
      };
      provisioning.shared_secret = "$MAUTRIX_WHATSAPP_PROVISIONING_SHARED_SECRET";
    };
  };

  services.matrix-synapse.settings.app_service_config_files = lib.mkIf matrixWhatsappEnabled [
    matrixWhatsappRegistrationFile
  ];

  # Put the bridge's dedicated database rule before the generic loopback rules
  # from the PostgreSQL module. The URI is loopback-only and the password is
  # supplied through the bridge's SOPS-rendered environment file.
  services.postgresql.authentication = lib.mkIf matrixWhatsappEnabled (
    lib.mkBefore ''
      host    mautrix-whatsapp    mautrix-whatsapp    127.0.0.1/32    scram-sha-256
    ''
  );

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/matrix-synapse 0700 matrix-synapse matrix-synapse -"
      "d /var/lib/postgresql 0700 postgres postgres -"
      "d /var/lib/mas 0700 mas mas -"
    ]
    ++ lib.optional matrixWhatsappEnabled
      "d /var/lib/mautrix-whatsapp 0700 mautrix-whatsapp mautrix-whatsapp -";

    services = {
      matrix-synapse = lib.mkIf matrixWhatsappEnabled {
        after = [
          "sops-install-secrets.service"
          "mautrix-whatsapp-registration.service"
        ];
        requires = [
          "sops-install-secrets.service"
          "mautrix-whatsapp-registration.service"
        ];
        restartTriggers = [ matrixWhatsappSettingsUnsubstituted ];
        serviceConfig.SupplementaryGroups = [ matrixWhatsappRegistrationGroup ];
      };

      mautrix-whatsapp-db-init = lib.mkIf matrixWhatsappEnabled {
        description = "Create the dedicated Mautrix-WhatsApp PostgreSQL database";
        after = [ "postgresql.service" ];
        requires = [ "postgresql.service" ];
        before = [
          "mautrix-whatsapp-registration.service"
          "mautrix-whatsapp.service"
        ];
        serviceConfig = secretGeneratorHardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          User = config.services.postgresql.superUser;
          ReadOnlyPaths = [ matrixWhatsappDatabasePasswordPath ];
        };
        script = ''
          set -euo pipefail
          bridgeDatabasePassword="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg matrixWhatsappDatabasePasswordPath})"
          test -n "$bridgeDatabasePassword"
          ${config.services.postgresql.package}/bin/psql -tc \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            "SELECT 1 FROM pg_roles WHERE rolname='mautrix-whatsapp'" | \
            ${pkgs.gnugrep}/bin/grep -q 1 || \
            ${config.services.postgresql.package}/bin/psql \
              --no-psqlrc \
              --set=ON_ERROR_STOP=1 \
              -c \
              'CREATE ROLE "mautrix-whatsapp" WITH LOGIN'
          ${config.services.postgresql.package}/bin/psql -tc \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            "SELECT 1 FROM pg_database WHERE datname='mautrix-whatsapp'" | \
            ${pkgs.gnugrep}/bin/grep -q 1 || \
            ${config.services.postgresql.package}/bin/psql \
              --no-psqlrc \
              --set=ON_ERROR_STOP=1 \
              -c \
              "CREATE DATABASE \"mautrix-whatsapp\" WITH OWNER \"mautrix-whatsapp\" TEMPLATE template0 LC_COLLATE = 'C' LC_CTYPE = 'C'"
          BRIDGE_DATABASE_PASSWORD="$bridgeDatabasePassword" \
          ${config.services.postgresql.package}/bin/psql \
              --no-psqlrc \
              --set=ON_ERROR_STOP=1 <<'EOF'
          \getenv bridge_password BRIDGE_DATABASE_PASSWORD
          SET password_encryption = 'scram-sha-256';
          ALTER ROLE "mautrix-whatsapp" PASSWORD :'bridge_password';
          EOF
        '';
      };

      mautrix-whatsapp-registration = lib.mkIf matrixWhatsappEnabled {
        description = "Prepare the Mautrix-WhatsApp appservice registration";
        after = [
          "sops-install-secrets.service"
          "mautrix-whatsapp-db-init.service"
        ];
        requires = [
          "sops-install-secrets.service"
          "mautrix-whatsapp-db-init.service"
        ];
        before = [
          "matrix-synapse.service"
          "mautrix-whatsapp.service"
        ];
        partOf = [ "matrix-synapse.service" ];
        path = [
          pkgs.envsubst
          pkgs.yq
          pkgs.coreutils
        ];
        serviceConfig = secretGeneratorHardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "mautrix-whatsapp";
          Group = matrixWhatsappRegistrationGroup;
          UMask = "0027";
          EnvironmentFile = matrixWhatsappEnvironmentFile;
          RuntimeDirectory = "matrix-whatsapp-registration";
          RuntimeDirectoryMode = "0750";
          WorkingDirectory = matrixWhatsappDataDir;
          ReadWritePaths = [
            matrixWhatsappDataDir
            matrixWhatsappRegistrationDirectory
          ];
          RestrictAddressFamilies = [ "AF_UNIX" ];
        };
        restartTriggers = [ matrixWhatsappSettingsUnsubstituted ];
        script = ''
          set -euo pipefail
          old_umask=$(umask)
          umask 0177
          cleanup() {
            rm -f -- \
              ${lib.escapeShellArg matrixWhatsappSettingsRenderedFile} \
              ${lib.escapeShellArg matrixWhatsappSettingsTempFile} \
              ${lib.escapeShellArg matrixWhatsappRegistrationTempFile}
          }
          trap cleanup EXIT

          for unit in matrix-synapse.service mautrix-whatsapp.service; do
            if ${pkgs.systemd}/bin/systemctl is-active --quiet "$unit"; then
              echo "Refusing to replace the appservice registration while $unit is running" >&2
              exit 1
            fi
          done

          ${pkgs.envsubst}/bin/envsubst \
            -o ${lib.escapeShellArg matrixWhatsappSettingsRenderedFile} \
            -i ${lib.escapeShellArg matrixWhatsappSettingsUnsubstituted}

          ${config.services.mautrix-whatsapp.package}/bin/mautrix-whatsapp \
            --generate-registration \
            --config=${lib.escapeShellArg matrixWhatsappSettingsRenderedFile} \
            --registration=${lib.escapeShellArg matrixWhatsappRegistrationTempFile}
          chmod 0640 ${lib.escapeShellArg matrixWhatsappRegistrationTempFile}
          mv -- \
            ${lib.escapeShellArg matrixWhatsappRegistrationTempFile} \
            ${lib.escapeShellArg matrixWhatsappRegistrationFile}

          ${pkgs.yq}/bin/yq -s '.[0].appservice.as_token = .[1].as_token
            | .[0].appservice.hs_token = .[1].hs_token
            | .[0]' \
            ${lib.escapeShellArg matrixWhatsappSettingsRenderedFile} \
            ${lib.escapeShellArg matrixWhatsappRegistrationFile} \
            > ${lib.escapeShellArg matrixWhatsappSettingsTempFile}
          mv -- ${lib.escapeShellArg matrixWhatsappSettingsTempFile} \
            ${lib.escapeShellArg matrixWhatsappSettingsFile}
          umask $old_umask
        '';
      };

      mautrix-whatsapp = lib.mkIf matrixWhatsappEnabled {
        after = [
          "sops-install-secrets.service"
          "mautrix-whatsapp-registration.service"
          "mautrix-whatsapp-db-init.service"
          "matrix-synapse.service"
        ];
        requires = [
          "sops-install-secrets.service"
          "mautrix-whatsapp-registration.service"
          "mautrix-whatsapp-db-init.service"
          "matrix-synapse.service"
        ];
        partOf = [ "matrix-synapse.service" ];
        # The locked mautrix module supplies ffmpeg-headless; LottieConverter
        # is added for animated sticker conversion.
        path = [
          pkgs.ffmpeg-headless
          pkgs.lottieconverter
        ];
        # The upstream preStart can generate a registration after Synapse has
        # already started. This gate owns registration generation instead and
        # fails closed if the coordinated registration file is unavailable.
        preStart = lib.mkForce ''
          if [ ! -s ${lib.escapeShellArg matrixWhatsappRegistrationFile} ]; then
            echo "Mautrix-WhatsApp registration is missing; restart the registration gate with Synapse and the bridge stopped" >&2
            exit 1
          fi
        '';
        serviceConfig = {
          PrivateUsers = true;
          StateDirectoryMode = "0700";
          MemoryHigh = "512M";
          MemoryMax = "1G";
          CPUWeight = 50;
          TasksMax = 256;
          ExecStart = lib.mkForce ''
            ${config.services.mautrix-whatsapp.package}/bin/mautrix-whatsapp \
              --config=${lib.escapeShellArg matrixWhatsappSettingsFile} \
              --registration=${lib.escapeShellArg matrixWhatsappRegistrationFile}
          '';
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
          ReadOnlyPaths = [
            matrixWhatsappEnvironmentFile
            matrixWhatsappRegistrationFile
          ];
          ReadWritePaths = [ matrixWhatsappDataDir ];
        };
      };

      # Assembles Synapse's runtime config with its shared secret and MSC3861
      # auth delegation block. Shallow-merged by Synapse on top of the main
      # config. MAS owns all Matrix SMTP configuration.
      matrix-synapse-secret = {
        description = "Generate Matrix Synapse secret + auth delegation config";
        before = [ "matrix-synapse.service" ];
        requiredBy = [ "matrix-synapse.service" ];
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
        serviceConfig = secretGeneratorHardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "matrix-synapse";
          Group = "matrix-synapse";
          UMask = "0337";
          RuntimeDirectory = "matrix-synapse-secret";
          RuntimeDirectoryMode = "0750";
          ReadOnlyPaths = [
            config.sops.secrets."matrix-synapse/registration_shared_secret".path
          ]
          ++
            lib.optional config.sys.services.matrix-synapse.authDelegation.enable
              config.sops.secrets."matrix-authentication-service/synapse_secret".path;
          ReadWritePaths = [ "/run/matrix-synapse-secret" ];
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
              ${masArgs} \
              '{
                registration_shared_secret: ($secret | rtrimstr("\n"))
              }${masJqExpr}' \
              > /run/matrix-synapse-secret/shared-secret.yaml
          '';
      };

      # Assembles MAS runtime config by merging the Nix-generated base
      # config with decrypted secrets (encryption key, signing keys,
      # Synapse shared secret, OIDC client secret, and MAS's SMTP token).
      mas-secret = {
        description = "Generate MAS runtime config with secrets";
        before = [ "matrix-authentication-service.service" ];
        requiredBy = [ "matrix-authentication-service.service" ];
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
        serviceConfig = secretGeneratorHardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "mas";
          Group = "mas";
          UMask = "0337";
          RuntimeDirectory = masRuntimeDirectory;
          RuntimeDirectoryMode = "0750";
          ReadOnlyPaths = [
            "/etc/matrix-authentication-service/config.json"
            config.sops.secrets."matrix-authentication-service/encryption_key".path
            config.sops.secrets."matrix-authentication-service/signing_key_rsa".path
            config.sops.secrets."matrix-authentication-service/signing_key_ec_p256".path
            config.sops.secrets."matrix-authentication-service/signing_key_ec_p384".path
            config.sops.secrets."matrix-authentication-service/signing_key_ec_secp256k1".path
            config.sops.secrets."matrix-authentication-service/synapse_secret".path
            config.sops.secrets."matrix-authentication-service/client_secret".path
            config.sops.secrets."matrix-authentication-service/smtp_token".path
          ];
          ReadWritePaths = [ masRuntimeConfigDirectory ];
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
            --rawfile smtp_pass ${config.sops.secrets."matrix-authentication-service/smtp_token".path} \
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
            > ${masRuntimeConfigFile}
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
        openFirewall = false;
        bindAddress = "127.0.0.1";
        trustedProxies = [ "127.0.0.1/32" ];

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
          endpoint = "http://127.0.0.1:8008/";
        };

        clientId = "0000000000000000000SYNAPSE";

        runtimeConfigFile = "/run/mas-secret/config.json";

        # Keep existing password login and recovery while closing anonymous
        # password registration before the later OIDC migration.
        settings = {
          # Keep bcrypt as scheme v1 for imported Synapse hashes. Successful
          # logins upgrade compatible hashes to argon2id (v2); new password
          # registration is disabled below.
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
            password_registration_enabled = false;
            password_recovery_enabled = true;
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
        bindAddress = "127.0.0.1";

        database.createLocally = true;
        urlPreview.enable = true;

        autoCompressor = {
          enable = true;
          interval = "daily";
          chunksToCompress = 1000;
        };

        vacuumTimer.enable = true;
        dbSizeLogger.enable = true;

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
          masEndpoint = "http://127.0.0.1:${toString config.sys.services.matrix-authentication-service.port}/";
        };

        settings = {
          # Let users browse other servers' public room directories
          allow_public_rooms_over_federation = true;

          # QR code device linking (MSC4108) - exposes /_synapse/client/rendezvous
          # and advertises support in /versions for Element's "Link new device" flow
          experimental_features.msc4108_enabled = true;

          # Suppress warning about trusting the default matrix.org key server
          suppress_key_server_warning = true;

          # Auto-purge media after inactivity: remote 90d, local uploads 2y
          media_retention = {
            remote_media_lifetime = "90d";
            local_media_lifetime = "2y";
          };

          # Server-wide event retention: purge messages older than 2y.
          # Does not affect state events; federated servers enforce their own policy.
          retention = {
            enabled = true;
            default_policy = {
              min_lifetime = "1d";
              max_lifetime = "2y";
            };
            allowed_lifetime_min = "1d";
            allowed_lifetime_max = "10y";
            purge_jobs = [
              {
                longest_max_lifetime = "3d";
                interval = "12h";
              }
              {
                shortest_max_lifetime = "3d";
                longest_max_lifetime = "1w";
                interval = "1d";
              }
              {
                shortest_max_lifetime = "1w";
                interval = "2d";
              }
            ];
          };

          # Allow uploads up to 90 MB
          max_upload_size = "90M";

          # Disable presence (online/offline tracking) to reduce resource usage
          presence.enabled = false;

          # Disable Synapse's built-in well-known - Nginx handles it
          serve_server_wellknown = false;

          # --- Access control ---
          # Registration and password policy are now managed by MAS.
          # These Synapse-side settings remain for non-auth access control.

          allow_guest_access = false;
          allow_public_rooms_without_auth = false;
          require_auth_for_profile_requests = true;
          limit_profile_requests_to_users_who_share_rooms = true;

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
    enableReload = true;

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

      locations = matrixRoutes.locations // {
        # --- MAS compatibility layer ---
        # Route Synapse login/logout/refresh to MAS so legacy and OIDC
        # clients both work through the same endpoints.
        # Keep Synapse administration on the local SSH/loopback path. The
        # client rendezvous endpoint remains in the Synapse catch-all below.
        "~ ^/_synapse/admin(?:/|$)" = {
          return = "403";
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
    groups = {
      matrix-shared = { };
    } // lib.optionalAttrs matrixWhatsappEnabled {
      ${matrixWhatsappRegistrationGroup} = { };
    };
    users = {
      mas.extraGroups = [ "matrix-shared" ];
      matrix-synapse.extraGroups = [ "matrix-shared" ];
    };
  };
}
