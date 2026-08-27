{
  matrix,
  blizzard,
  VARS,
  pkgs,
  ...
}:
let
  inherit (pkgs) lib;
  matrixWithBridge = matrix.extendModules {
    modules = [
      {
        services.mautrix-whatsapp.enable = lib.mkForce true;
      }
    ];
  };
  defaultVmCfg = matrix.config;
  vmCfg = matrixWithBridge.config;
  hostCfg = blizzard.config;
  bridge = vmCfg.services.mautrix-whatsapp;
  bridgeSettings = bridge.settings;
  bridgeService = vmCfg.systemd.services."mautrix-whatsapp";
  dbInitService = vmCfg.systemd.services."mautrix-whatsapp-db-init";
  registrationService = vmCfg.systemd.services."mautrix-whatsapp-registration";
  synapseService = vmCfg.systemd.services."matrix-synapse";
  bridgeVolume = lib.findFirst (
    volume: volume.mountPoint == "/var/lib/mautrix-whatsapp"
  ) null vmCfg.microvm.volumes;
  matrixInstance = hostCfg.sys.virtualisation.microvm.instances.matrix-synapse;
  bridgeAdmin = "@telometto:${VARS.domains.public}";
  bridgeRegistrationGroup = "matrix-whatsapp-registration";
  bridgeEnvironment = vmCfg.sops.templates."matrix-whatsapp-environment";
  bridgeDatabaseSecret = vmCfg.sops.secrets."matrix-whatsapp/database_password";
  registrationScript = pkgs.writeText "matrix-whatsapp-registration.sh" registrationService.script;
  dbInitScript = pkgs.writeText "matrix-whatsapp-db-init.sh" dbInitService.script;
  bridgePreStartScript = pkgs.writeText "matrix-whatsapp-pre-start.sh" bridgeService.preStart;
  matrixFirewallAllow = vmCfg.networking.firewall.extraCommands;
  registrationTestDataDir = "/tmp/matrix-whatsapp-bridge-test-data";
  registrationTestRuntimeDir = "/tmp/matrix-whatsapp-bridge-test-runtime";
  fakeSystemctlInactive = pkgs.writeShellScriptBin "systemctl" ''
    exit 3
  '';
  fakeSystemctlActive = pkgs.writeShellScriptBin "systemctl" ''
    exit 0
  '';
  fakeEnvsubst = pkgs.writeShellScriptBin "envsubst" ''
    set -eu
    input=
    output=
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -i)
          input="$2"
          shift 2
          ;;
        -o)
          output="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    cp "$input" "$output"
  '';
  fakeMautrix = pkgs.writeShellScriptBin "mautrix-whatsapp" ''
    set -eu
    registration=
    for argument in "$@"; do
      case "$argument" in
        --registration=*) registration="''${argument#--registration=}" ;;
      esac
    done
    test -n "$registration"
    cat > "$registration" <<'EOF'
    as_token: generated-as-token
    hs_token: generated-hs-token
    EOF
  '';
  fakeYq = pkgs.writeShellScriptBin "yq" ''
    set -eu
    cat "$3"
  '';
  fakePsql = pkgs.writeShellScriptBin "psql" ''
    set -euo pipefail
    test -n "''${PSQL_TEST_LOG:?}"
    query=
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -c)
          query="$2"
          shift 2
          ;;
        SELECT*)
          echo "missing \"=\" after \"$1\" in connection info string" >&2
          exit 2
          ;;
        *)
          shift
          ;;
      esac
    done

    case "$query" in
      "SELECT 1 FROM pg_roles"*|"SELECT 1 FROM pg_database"*)
        printf ' 1\n'
        ;;
      "CREATE ROLE"*|"CREATE DATABASE"*)
        printf '%s\n' "$query" >> "''${PSQL_TEST_LOG}"
        ;;
      "")
        ${pkgs.coreutils}/bin/cat >/dev/null
        ;;
      *)
        printf '%s\n' "$query" >> "''${PSQL_TEST_LOG}"
        ;;
    esac
  '';
  dbInitTestDataDir = "/tmp/matrix-whatsapp-db-init-test-data";
  dbInitTestPasswordFile = "${dbInitTestDataDir}/database-password";
  dbInitTestLog = "${dbInitTestDataDir}/psql.log";
  dbInitExistingObjectsScript = pkgs.writeText "matrix-whatsapp-db-init-existing-objects.sh" (
    lib.replaceStrings
      [
        "${vmCfg.services.postgresql.package}/bin/psql"
        bridgeDatabaseSecret.path
      ]
      [
        "${fakePsql}/bin/psql"
        dbInitTestPasswordFile
      ]
      dbInitService.script
  );
  dbInitExistingObjectsCheck = pkgs.runCommand "matrix-whatsapp-db-init-existing-objects-test" { } ''
    set -euo pipefail
    mkdir -p ${dbInitTestDataDir}
    printf 'test-password\n' > ${dbInitTestPasswordFile}
    : > ${dbInitTestLog}
    export PSQL_TEST_LOG=${dbInitTestLog}
    ${pkgs.bash}/bin/bash ${dbInitExistingObjectsScript}
    if ${pkgs.gnugrep}/bin/grep -Eq '^CREATE (ROLE|DATABASE) ' ${dbInitTestLog}; then
      echo "existing PostgreSQL objects were recreated" >&2
      ${pkgs.coreutils}/bin/cat ${dbInitTestLog} >&2
      exit 1
    fi
    touch "$out"
  '';
  registrationScriptFor =
    systemctl:
    lib.replaceStrings
      [
        "${pkgs.systemd}/bin/systemctl"
        "${pkgs.envsubst}/bin/envsubst"
        "${bridge.package}/bin/mautrix-whatsapp"
        "${pkgs.yq}/bin/yq"
        "/var/lib/mautrix-whatsapp"
        "/run/matrix-whatsapp-registration"
      ]
      [
        "${systemctl}/bin/systemctl"
        "${fakeEnvsubst}/bin/envsubst"
        "${fakeMautrix}/bin/mautrix-whatsapp"
        "${fakeYq}/bin/yq"
        registrationTestDataDir
        registrationTestRuntimeDir
      ]
      registrationService.script;
  registrationInactiveScript = pkgs.writeText "matrix-whatsapp-registration-inactive.sh" (
    registrationScriptFor fakeSystemctlInactive
  );
  registrationActiveScript = pkgs.writeText "matrix-whatsapp-registration-active.sh" (
    registrationScriptFor fakeSystemctlActive
  );
  scriptSyntaxCheck = pkgs.runCommand "matrix-whatsapp-bridge-script-syntax" { } ''
    ${pkgs.bash}/bin/bash -n ${registrationScript}
    ${pkgs.bash}/bin/bash -n ${dbInitScript}
    ${pkgs.bash}/bin/bash -n ${bridgePreStartScript}
    touch "$out"
  '';
  registrationLifecycleCheck = pkgs.runCommand "matrix-whatsapp-bridge-registration-test" { } ''
    set -euo pipefail
    mkdir -p ${registrationTestDataDir} ${registrationTestRuntimeDir}
    ${pkgs.bash}/bin/bash ${registrationInactiveScript}
    test -s ${registrationTestRuntimeDir}/whatsapp-registration.yaml
    test -s ${registrationTestDataDir}/config.yaml

    printf 'existing-registration\n' > ${registrationTestRuntimeDir}/whatsapp-registration.yaml
    if ${pkgs.bash}/bin/bash ${registrationActiveScript}; then
      echo "registration replacement was not blocked while a protected service was active" >&2
      exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -q '^existing-registration$' ${registrationTestRuntimeDir}/whatsapp-registration.yaml
    touch "$out"
  '';
  bridgeSecrets = [
    "matrix-whatsapp/appservice_as_token"
    "matrix-whatsapp/appservice_hs_token"
    "matrix-whatsapp/provisioning_shared_secret"
    "matrix-whatsapp/encryption_pickle_key"
    "matrix-whatsapp/public_media_signing_key"
    "matrix-whatsapp/direct_media_server_key"
  ];
in
assert !defaultVmCfg.services.mautrix-whatsapp.enable;
assert !(builtins.hasAttr "matrix-whatsapp/database_password" defaultVmCfg.sops.secrets);
assert !(builtins.hasAttr "mautrix-whatsapp" defaultVmCfg.systemd.services);
assert
  !(lib.any (volume: volume.mountPoint == "/var/lib/mautrix-whatsapp") defaultVmCfg.microvm.volumes);
assert lib.hasInfix "--dport 11060 -s 10.100.0.1 -j nixos-fw-accept" matrixFirewallAllow;
assert lib.hasInfix "-i ens+" matrixFirewallAllow;
assert bridge.enable;
assert !bridge.registerToSynapse;
assert bridgeSettings.homeserver.address == "http://127.0.0.1:8008";
assert bridgeSettings.homeserver.domain == VARS.domains.public;
assert bridgeSettings.appservice.address == "http://127.0.0.1:29318";
assert bridgeSettings.appservice.hostname == "127.0.0.1";
assert bridgeSettings.appservice.port == 29318;
assert !(bridgeSettings.appservice ? public_address);
assert bridgeSettings.bridge.federate_rooms == false;
assert bridgeSettings.network.history_sync.request_full_sync == false;
assert bridgeSettings.database.type == "postgres";
assert
  bridgeSettings.database.uri
  == "postgresql://mautrix-whatsapp@127.0.0.1/mautrix-whatsapp?sslmode=disable";
assert bridgeSettings.bridge.relay.enabled == false;
assert bridgeSettings.bridge.permissions."*" == "relay";
assert bridgeSettings.bridge.permissions.${bridgeAdmin} == "admin";
assert bridgeSettings.encryption.allow;
assert bridgeSettings.encryption.default;
assert bridgeSettings.encryption.require;
assert bridgeSettings.encryption.msc4190;
assert bridgeSettings.encryption.pickle_key == "$MAUTRIX_WHATSAPP_ENCRYPTION_PICKLE_KEY";
assert bridgeSettings.provisioning.shared_secret == "$MAUTRIX_WHATSAPP_PROVISIONING_SHARED_SECRET";
assert bridgeSettings.public_media.signing_key == "$MAUTRIX_WHATSAPP_PUBLIC_MEDIA_SIGNING_KEY";
assert bridgeSettings.direct_media.server_key == "$MAUTRIX_WHATSAPP_DIRECT_MEDIA_SERVER_KEY";
assert bridgeVolume != null;
assert bridgeVolume.image == "mautrix-whatsapp-state.img";
assert bridgeVolume.size == 10240;
assert lib.elem "/run/matrix-whatsapp-registration/whatsapp-registration.yaml"
  vmCfg.services.matrix-synapse.settings.app_service_config_files;
assert bridgeEnvironment.owner == "mautrix-whatsapp";
assert bridgeEnvironment.group == "mautrix-whatsapp";
assert bridgeEnvironment.mode == "0400";
assert lib.hasInfix "PGPASSWORD=" bridgeEnvironment.content;
assert lib.all (
  name:
  let
    secret = vmCfg.sops.secrets.${name};
  in
  secret.owner == "root" && secret.group == "mautrix-whatsapp" && secret.mode == "0440"
) bridgeSecrets;
assert bridgeDatabaseSecret.owner == "root";
assert bridgeDatabaseSecret.group == "postgres";
assert bridgeDatabaseSecret.mode == "0440";
assert lib.hasInfix "host    mautrix-whatsapp    mautrix-whatsapp    127.0.0.1/32    scram-sha-256"
  vmCfg.services.postgresql.authentication;
assert lib.elem "mautrix-whatsapp-db-init.service" bridgeDatabaseSecret.restartUnits;
assert lib.elem "mautrix-whatsapp-registration.service" bridgeDatabaseSecret.restartUnits;
assert lib.elem "matrix-synapse.service" bridgeDatabaseSecret.restartUnits;
assert lib.elem "mautrix-whatsapp.service" bridgeDatabaseSecret.restartUnits;
assert matrixInstance.portForward.enable == false;
assert matrixInstance.portForward.ports == [ ];
assert vmCfg.networking.firewall.allowedTCPPorts == [ ];
assert builtins.hasAttr bridgeRegistrationGroup vmCfg.users.groups;
assert lib.elem bridgeRegistrationGroup synapseService.serviceConfig.SupplementaryGroups;
assert !(lib.elem "mautrix-whatsapp" synapseService.serviceConfig.SupplementaryGroups);
assert registrationService.serviceConfig.Type == "oneshot";
assert registrationService.serviceConfig.User == "mautrix-whatsapp";
assert registrationService.serviceConfig.Group == bridgeRegistrationGroup;
assert registrationService.serviceConfig.EnvironmentFile == bridgeEnvironment.path;
assert registrationService.serviceConfig.RuntimeDirectory == "matrix-whatsapp-registration";
assert registrationService.serviceConfig.RuntimeDirectoryMode == "0750";
assert lib.elem "matrix-synapse.service" registrationService.before;
assert lib.elem "mautrix-whatsapp.service" registrationService.before;
assert lib.elem "mautrix-whatsapp-db-init.service" registrationService.requires;
assert lib.elem "mautrix-whatsapp-db-init.service" registrationService.after;
assert lib.elem "mautrix-whatsapp-registration.service" synapseService.requires;
assert lib.elem "mautrix-whatsapp-registration.service" synapseService.after;
assert lib.elem "matrix-synapse.service" registrationService.partOf;
assert registrationService.restartTriggers != [ ];
assert synapseService.restartTriggers != [ ];
assert lib.hasInfix "--generate-registration" registrationService.script;
assert lib.hasInfix "is-active --quiet \"$unit\"" registrationService.script;
assert lib.hasInfix "mautrix-whatsapp.service" registrationService.script;
assert lib.hasInfix "/run/matrix-whatsapp-registration/whatsapp-registration.yaml"
  bridgeService.preStart;
assert dbInitService.serviceConfig.Type == "oneshot";
assert dbInitService.serviceConfig.User == vmCfg.services.postgresql.superUser;
assert lib.elem bridgeDatabaseSecret.path dbInitService.serviceConfig.ReadOnlyPaths;
assert lib.hasInfix "ALTER ROLE" dbInitService.script;
assert lib.hasInfix "SET password_encryption = 'scram-sha-256'" dbInitService.script;
assert lib.hasInfix "\\getenv bridge_password BRIDGE_DATABASE_PASSWORD" dbInitService.script;
assert !(lib.hasInfix "--set=bridge_password" dbInitService.script);
assert lib.hasInfix "/var/lib/mautrix-whatsapp/config.yaml" bridgeService.serviceConfig.ExecStart;
assert lib.hasInfix "/run/matrix-whatsapp-registration/whatsapp-registration.yaml"
  bridgeService.serviceConfig.ExecStart;
assert lib.elem "mautrix-whatsapp-db-init.service" bridgeService.requires;
assert lib.elem "mautrix-whatsapp-registration.service" bridgeService.requires;
assert lib.elem "mautrix-whatsapp-registration.service" bridgeService.after;
assert lib.elem "matrix-synapse.service" bridgeService.requires;
assert lib.elem "matrix-synapse.service" bridgeService.after;
assert lib.elem "matrix-synapse.service" bridgeService.partOf;
assert bridgeService.serviceConfig.User == "mautrix-whatsapp";
assert bridgeService.serviceConfig.PrivateUsers == true;
assert bridgeService.serviceConfig.StateDirectoryMode == "0700";
assert bridgeService.serviceConfig.MemoryHigh == "512M";
assert bridgeService.serviceConfig.MemoryMax == "1G";
assert bridgeService.serviceConfig.TasksMax == 256;
assert lib.elem pkgs.ffmpeg-headless bridgeService.path;
assert lib.elem pkgs.lottieconverter bridgeService.path;
pkgs.runCommand "matrix-whatsapp-bridge-tests" { } ''
  test -e ${scriptSyntaxCheck}
  test -e ${registrationLifecycleCheck}
  test -e ${dbInitExistingObjectsCheck}
  touch "$out"
''
