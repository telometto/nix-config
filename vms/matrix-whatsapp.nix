{
  lib,
  config,
  pkgs,
  VARS,
  ...
}:
let
  matrixWhatsappEnabled = config.services.mautrix-whatsapp.enable;
  matrixWhatsappDataDir = "/var/lib/mautrix-whatsapp";
  matrixWhatsappRegistrationGroup = "matrix-whatsapp-registration";
  matrixWhatsappRegistrationDirectory = "/run/matrix-whatsapp-registration";
  matrixWhatsappRegistrationCurrentDirectory = "${matrixWhatsappRegistrationDirectory}/current";
  matrixWhatsappSettingsFile = "${matrixWhatsappRegistrationCurrentDirectory}/config.yaml";
  matrixWhatsappRegistrationFile = "${matrixWhatsappRegistrationCurrentDirectory}/whatsapp-registration.yaml";
  matrixWhatsappStackTarget = "mautrix-whatsapp-stack.target";
  matrixWhatsappEnvironmentFile = config.sops.templates."matrix-whatsapp-environment".path;
  matrixWhatsappDatabasePasswordPath = config.sops.secrets."matrix-whatsapp/database_password".path;
  matrixWhatsappRestartUnits = [
    "mautrix-whatsapp-stack-reconcile.service"
  ];
  # The bridge needs loopback access to Synapse and PostgreSQL, plus public
  # WhatsApp endpoints. Deny private, link-local, and CGNAT destinations so a
  # compromised bridge cannot pivot to the VM network or the host LAN.
  matrixWhatsappBlockedNetworks = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10"
    "169.254.0.0/16"
    "fc00::/7"
    "fe80::/10"
  ];
  matrixWhatsappSettingsFormat = pkgs.formats.json { };
  matrixWhatsappSettings = config.services.mautrix-whatsapp.settings // {
    bridge = config.services.mautrix-whatsapp.settings.bridge // {
      permissions = lib.removeAttrs config.services.mautrix-whatsapp.settings.bridge.permissions [ "*" ];
    };
  };
  matrixWhatsappSettingsUnsubstituted = matrixWhatsappSettingsFormat.generate "mautrix-whatsapp-config-unsubstituted.json" matrixWhatsappSettings;
  # This is the Matrix account, not the VM's admin account or the operator's
  # Unix username.
  matrixWhatsappAdmin = "@telometto:${VARS.domains.public}";
  matrixStorage = import ./matrix-storage.nix;
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
  assertions = lib.optionals matrixWhatsappEnabled [
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

  # Keep the optional bridge image in the same MicroVM volume definition as the
  # Matrix-owned images. The storage contract is shared with the host backup.
  microvm.volumes = lib.mkIf matrixWhatsappEnabled (
    lib.mkAfter [ (matrixStorage.toMicrovmVolume matrixStorage.bridgeVolume) ]
  );

  sops = {
    secrets = lib.optionalAttrs matrixWhatsappEnabled {
      # Mautrix-WhatsApp appservice and bridge secrets. Values are consumed
      # through the SOPS-rendered environment file below and never enter the
      # Nix-generated bridge configuration.
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

  services = {
    mautrix-whatsapp = {
      # Keep the integration opt-in until private SOPS values, backup evidence,
      # and interactive-login acceptance have been completed.
      enable = lib.mkDefault false;
      # libolm is deprecated upstream. The locked mautrix-whatsapp package's
      # available non-libolm backend is goolm; keep this explicit until the
      # bridge provides a supported, audited vodozemac-backed alternative.
      package = pkgs.mautrix-whatsapp.override { withGoolm = true; };
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
          # MAS does not expose the legacy m.login.application_service flow.
          # Use MSC4190 device creation for the encrypted bridge bot instead.
          msc4190 = true;
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

    matrix-synapse.settings.app_service_config_files = lib.mkIf matrixWhatsappEnabled [
      matrixWhatsappRegistrationFile
    ];

    # Put the bridge's dedicated database rule before the generic loopback rules
    # from the PostgreSQL module. The URI is loopback-only and the password is
    # supplied through the bridge's SOPS-rendered environment file.
    postgresql.authentication = lib.mkIf matrixWhatsappEnabled (
      lib.mkBefore ''
        host    mautrix-whatsapp    mautrix-whatsapp    127.0.0.1/32    scram-sha-256
      ''
    );
  };

  systemd = {
    tmpfiles.rules = lib.mkAfter (
      lib.optional matrixWhatsappEnabled "d /var/lib/mautrix-whatsapp 0700 mautrix-whatsapp mautrix-whatsapp -"
    );

    targets.mautrix-whatsapp-stack = lib.mkIf matrixWhatsappEnabled {
      description = "Coordinated Matrix and Mautrix-WhatsApp service stack";
      requires = [
        "sops-install-secrets.service"
        "postgresql.service"
        "mautrix-whatsapp-db-init.service"
        "mautrix-whatsapp-registration.service"
        "matrix-synapse.service"
        "mautrix-whatsapp.service"
      ];
      after = [
        "sops-install-secrets.service"
        "postgresql.service"
        "mautrix-whatsapp-db-init.service"
        "mautrix-whatsapp-registration.service"
        "matrix-synapse.service"
        "mautrix-whatsapp.service"
      ];
      # A database restart must tear down and recreate the oneshot database and
      # registration gates before the consumers are started again.
      bindsTo = [ "postgresql.service" ];
      partOf = [ "postgresql.service" ];
    };

    services = {
      postgresql = lib.mkIf matrixWhatsappEnabled {
        # Starting PostgreSQL after a crash or planned restart must bring the
        # complete bridge stack back through the ordered target.
        wants = [ matrixWhatsappStackTarget ];
      };

      matrix-synapse = lib.mkIf matrixWhatsappEnabled {
        after = [ "mautrix-whatsapp-registration.service" ];
        requires = [ "mautrix-whatsapp-registration.service" ];
        wantedBy = lib.mkForce [ ];
        partOf = [ matrixWhatsappStackTarget ];
        serviceConfig.SupplementaryGroups = [ matrixWhatsappRegistrationGroup ];
      };

      mautrix-whatsapp-stack-reconcile = lib.mkIf matrixWhatsappEnabled {
        description = "Start or restart the Matrix and Mautrix-WhatsApp stack transactionally";
        wantedBy = [ "multi-user.target" ];
        after = [
          "sops-install-secrets.service"
          "postgresql.service"
          matrixWhatsappStackTarget
        ];
        requires = [
          "sops-install-secrets.service"
          "postgresql.service"
        ];
        restartTriggers = [
          matrixWhatsappSettingsUnsubstituted
          config.services.mautrix-whatsapp.package
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.systemd}/bin/systemctl restart ${matrixWhatsappStackTarget}";
        };
      };

      mautrix-whatsapp-db-init = lib.mkIf matrixWhatsappEnabled {
        description = "Create the dedicated Mautrix-WhatsApp PostgreSQL database";
        after = [
          "sops-install-secrets.service"
          "postgresql.service"
        ];
        requires = [
          "sops-install-secrets.service"
          "postgresql.service"
        ];
        before = [
          "mautrix-whatsapp-registration.service"
          "mautrix-whatsapp.service"
        ];
        partOf = [ matrixWhatsappStackTarget ];
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
          roleExists="$(${config.services.postgresql.package}/bin/psql \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            --tuples-only \
            --no-align \
            -c \
            "SELECT 1 FROM pg_roles WHERE rolname='mautrix-whatsapp'")"
          if [ "$roleExists" != "1" ]; then
            ${config.services.postgresql.package}/bin/psql \
              --no-psqlrc \
              --set=ON_ERROR_STOP=1 \
              -c \
              'CREATE ROLE "mautrix-whatsapp" WITH LOGIN'
          fi
          databaseExists="$(${config.services.postgresql.package}/bin/psql \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            --tuples-only \
            --no-align \
            -c \
            "SELECT 1 FROM pg_database WHERE datname='mautrix-whatsapp'")"
          if [ "$databaseExists" != "1" ]; then
            ${config.services.postgresql.package}/bin/psql \
              --no-psqlrc \
              --set=ON_ERROR_STOP=1 \
              -c \
              "CREATE DATABASE \"mautrix-whatsapp\" WITH OWNER \"mautrix-whatsapp\" TEMPLATE template0 LC_COLLATE = 'C' LC_CTYPE = 'C'"
          fi
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
        partOf = [ matrixWhatsappStackTarget ];
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
        script = ''
          set -euo pipefail
          old_umask=$(umask)
          umask 0177
          registrationDirectory=${lib.escapeShellArg matrixWhatsappRegistrationDirectory}
          currentLink="$registrationDirectory/current"
          generationDirectory="$registrationDirectory/.generation-$$"
          generationLink="$registrationDirectory/.current-$$"
          oldGeneration=

          cleanup() {
            if [ -n "$generationDirectory" ]; then
              rm -rf -- "$generationDirectory"
            fi
            if [ -n "$generationLink" ]; then
              rm -f -- "$generationLink"
            fi
          }
          trap cleanup EXIT

          if [ -e "$currentLink" ] && [ ! -L "$currentLink" ]; then
            echo "Refusing to replace non-symlink registration state at $currentLink" >&2
            exit 1
          fi

          for unit in matrix-synapse.service mautrix-whatsapp.service; do
            if ${pkgs.systemd}/bin/systemctl is-active --quiet "$unit"; then
              echo "Refusing to replace the appservice registration while $unit is running" >&2
              exit 1
            fi
          done

          mkdir -- "$generationDirectory"
          chmod 0750 -- "$generationDirectory"

          ${pkgs.envsubst}/bin/envsubst \
            -no-unset \
            -no-empty \
            -fail-fast \
            -o "$generationDirectory/config.rendered.yaml" \
            -i ${lib.escapeShellArg matrixWhatsappSettingsUnsubstituted}

          ${config.services.mautrix-whatsapp.package}/bin/mautrix-whatsapp \
            --generate-registration \
            --config="$generationDirectory/config.rendered.yaml" \
            --registration="$generationDirectory/whatsapp-registration.yaml"
          chmod 0640 "$generationDirectory/whatsapp-registration.yaml"

          ${pkgs.yq}/bin/yq -s '.[0].appservice.as_token = .[1].as_token
            | .[0].appservice.hs_token = .[1].hs_token
            | .[0]' \
            "$generationDirectory/config.rendered.yaml" \
            "$generationDirectory/whatsapp-registration.yaml" \
            > "$generationDirectory/config.yaml"
          chmod 0600 "$generationDirectory/config.yaml"
          test -s "$generationDirectory/config.yaml"
          test -s "$generationDirectory/whatsapp-registration.yaml"
          ${pkgs.yq}/bin/yq -e '.appservice.as_token and .appservice.hs_token' \
            "$generationDirectory/config.yaml" >/dev/null

          ln -s -- "$(basename "$generationDirectory")" "$generationLink"
          if [ -L "$currentLink" ]; then
            oldGeneration="$(readlink -- "$currentLink")"
          fi
          mv -T -- "$generationLink" "$currentLink"
          generationDirectory=
          generationLink=

          case "$oldGeneration" in
            .generation-*)
              if ! rm -rf -- "$registrationDirectory/$oldGeneration"; then
                echo "Warning: failed to remove old registration generation $oldGeneration" >&2
              fi
              ;;
          esac

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
        partOf = [ matrixWhatsappStackTarget ];
        wantedBy = lib.mkForce [ ];
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
            "AF_INET"
            "AF_INET6"
          ];
          ReadOnlyPaths = [
            matrixWhatsappEnvironmentFile
            matrixWhatsappRegistrationFile
            matrixWhatsappSettingsFile
          ];
          IPAddressDeny = matrixWhatsappBlockedNetworks;
          ReadWritePaths = [ matrixWhatsappDataDir ];
        };
      };
    };
  };

  users.groups.${matrixWhatsappRegistrationGroup} = lib.mkIf matrixWhatsappEnabled { };
  users.users.matrix-synapse.extraGroups = lib.mkIf matrixWhatsappEnabled [
    matrixWhatsappRegistrationGroup
  ];
}
