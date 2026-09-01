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
  reconcileService = vmCfg.systemd.services."mautrix-whatsapp-stack-reconcile";
  postgresqlService = vmCfg.systemd.services.postgresql;
  stackTarget = vmCfg.systemd.targets."mautrix-whatsapp-stack";
  synapseService = vmCfg.systemd.services."matrix-synapse";
  bridgeVolume = lib.findFirst (
    volume: volume.mountPoint == "/var/lib/mautrix-whatsapp"
  ) null vmCfg.microvm.volumes;
  matrixInstance = hostCfg.sys.virtualisation.microvm.instances.matrix-synapse;
  bridgeAdmin = "@telometto:${VARS.domains.public}";
  bridgeRegistrationGroup = "matrix-whatsapp-registration";
  bridgeEnvironment = vmCfg.sops.templates."matrix-whatsapp-environment";
  bridgeDatabaseSecret = vmCfg.sops.secrets."matrix-whatsapp/database_password";
  matrixStorage = import ../vms/matrix-storage.nix;
  matrixBackupJob = hostCfg.services.borgbackup.jobs."matrix-rsyncnet";
  immichBackupJob = hostCfg.services.borgbackup.jobs."immich-rsyncnet";
  matrixBackupService = hostCfg.systemd.services."borgbackup-job-matrix-rsyncnet";
  matrixBackupPassphrase = hostCfg.sops.secrets."matrix-backup/borg-passphrase";
  registrationScript = pkgs.writeText "matrix-whatsapp-registration.sh" registrationService.script;
  dbInitScript = pkgs.writeText "matrix-whatsapp-db-init.sh" dbInitService.script;
  bridgePreStartScript = pkgs.writeText "matrix-whatsapp-pre-start.sh" bridgeService.preStart;
  matrixFirewallAllow = vmCfg.networking.firewall.extraCommands;
  registrationTestDataDir = "/tmp/matrix-whatsapp-bridge-test-data";
  registrationTestRuntimeDir = "/tmp/matrix-whatsapp-bridge-test-runtime";
  fakeSystemctlInactive = pkgs.writeShellScriptBin "systemctl" ''
    exit 3
  '';
  fakeSystemctlSynapseActive = pkgs.writeShellScriptBin "systemctl" ''
    if [ "''${3:-}" = matrix-synapse.service ]; then
      exit 0
    fi
    exit 3
  '';
  fakeSystemctlBridgeActive = pkgs.writeShellScriptBin "systemctl" ''
    if [ "''${3:-}" = mautrix-whatsapp.service ]; then
      exit 0
    fi
    exit 3
  '';
  fakeMautrixFailure = pkgs.writeShellScriptBin "mautrix-whatsapp" ''
    exit 42
  '';
  fakeMautrixMissingRegistration = pkgs.writeShellScriptBin "mautrix-whatsapp" ''
    exit 0
  '';
  fakeYqFailure = pkgs.writeShellScriptBin "yq" ''
    exit 43
  '';
  registrationScriptFor =
    systemctl: mautrixCommand:
    lib.replaceStrings
      [
        "${pkgs.systemd}/bin/systemctl"
        "${bridge.package}/bin/mautrix-whatsapp"
        "/var/lib/mautrix-whatsapp"
        "/run/matrix-whatsapp-registration"
      ]
      [
        "${systemctl}/bin/systemctl"
        mautrixCommand
        registrationTestDataDir
        registrationTestRuntimeDir
      ]
      registrationService.script;
  registrationInactiveScript = pkgs.writeText "matrix-whatsapp-registration-inactive.sh" (
    registrationScriptFor fakeSystemctlInactive "${bridge.package}/bin/mautrix-whatsapp"
  );
  registrationSynapseActiveScript = pkgs.writeText "matrix-whatsapp-registration-synapse-active.sh" (
    registrationScriptFor fakeSystemctlSynapseActive "${bridge.package}/bin/mautrix-whatsapp"
  );
  registrationBridgeActiveScript = pkgs.writeText "matrix-whatsapp-registration-bridge-active.sh" (
    registrationScriptFor fakeSystemctlBridgeActive "${bridge.package}/bin/mautrix-whatsapp"
  );
  registrationFailureScript = pkgs.writeText "matrix-whatsapp-registration-generator-failure.sh" (
    registrationScriptFor fakeSystemctlInactive "${fakeMautrixFailure}/bin/mautrix-whatsapp"
  );
  registrationMissingOutputScript = pkgs.writeText "matrix-whatsapp-registration-missing-output.sh" (
    registrationScriptFor fakeSystemctlInactive "${fakeMautrixMissingRegistration}/bin/mautrix-whatsapp"
  );
  registrationYqFailureScript = pkgs.writeText "matrix-whatsapp-registration-yq-failure.sh" (
    lib.replaceStrings [ "${pkgs.yq}/bin/yq" ] [ "${fakeYqFailure}/bin/yq" ] (
      registrationScriptFor fakeSystemctlInactive "${bridge.package}/bin/mautrix-whatsapp"
    )
  );
  scriptSyntaxCheck = pkgs.runCommand "matrix-whatsapp-bridge-script-syntax" { } ''
    ${pkgs.bash}/bin/bash -n ${registrationScript}
    ${pkgs.bash}/bin/bash -n ${dbInitScript}
    ${pkgs.bash}/bin/bash -n ${bridgePreStartScript}
    touch "$out"
  '';
  dbInitTestDataDir = "/tmp/matrix-whatsapp-db-init-test-data";
  dbInitTestPasswordFile = "${dbInitTestDataDir}/database-password";
  dbInitTestSuperuserPasswordFile = "${dbInitTestDataDir}/superuser-password";
  dbInitTestSocketDir = "${dbInitTestDataDir}/socket";
  dbInitTestScript = pkgs.writeText "matrix-whatsapp-db-init-real-postgresql.sh" (
    lib.replaceStrings [ bridgeDatabaseSecret.path ] [ dbInitTestPasswordFile ] dbInitService.script
  );
  dbInitScenariosCheck = pkgs.runCommand "matrix-whatsapp-db-init-real-postgresql-test" { } ''
    set -euo pipefail
    rm -rf ${dbInitTestDataDir}
    mkdir -p ${dbInitTestSocketDir}
    printf 'postgres-password\n' > ${dbInitTestSuperuserPasswordFile}
    ${vmCfg.services.postgresql.package}/bin/initdb \
      --no-sync \
      --auth-host=scram-sha-256 \
      --auth-local=scram-sha-256 \
      --username=postgres \
      --pwfile=${dbInitTestSuperuserPasswordFile} \
      ${dbInitTestDataDir}/postgres-data >/dev/null
    export PGHOST=${dbInitTestSocketDir}
    export PGPORT=55432
    export PGUSER=postgres
    export PGDATABASE=postgres
    export PGPASSWORD=postgres-password
    ${vmCfg.services.postgresql.package}/bin/pg_ctl \
      -D ${dbInitTestDataDir}/postgres-data \
      -o "-k $PGHOST -p $PGPORT" \
      -w start >/dev/null
    cleanup() {
      ${vmCfg.services.postgresql.package}/bin/pg_ctl \
        -D ${dbInitTestDataDir}/postgres-data \
        -m immediate \
        stop >/dev/null 2>&1 || true
    }
    trap cleanup EXIT

    printf 'test-password\n' > ${dbInitTestPasswordFile}
    ${pkgs.bash}/bin/bash ${dbInitTestScript}
    test "$(${vmCfg.services.postgresql.package}/bin/psql --no-psqlrc --tuples-only --no-align -c "SELECT 1 FROM pg_roles WHERE rolname='mautrix-whatsapp'")" = 1
    test "$(${vmCfg.services.postgresql.package}/bin/psql --no-psqlrc --tuples-only --no-align -c "SELECT 1 FROM pg_database WHERE datname='mautrix-whatsapp'")" = 1
    test "$(PGPASSWORD=test-password ${vmCfg.services.postgresql.package}/bin/psql --no-psqlrc -h 127.0.0.1 -p "$PGPORT" -U mautrix-whatsapp -d mautrix-whatsapp --tuples-only --no-align -c 'SELECT 1')" = 1

    printf 'rotated-password\n' > ${dbInitTestPasswordFile}
    ${pkgs.bash}/bin/bash ${dbInitTestScript}
    if PGPASSWORD=test-password ${vmCfg.services.postgresql.package}/bin/psql --no-psqlrc -h 127.0.0.1 -p "$PGPORT" -U mautrix-whatsapp -d mautrix-whatsapp --tuples-only --no-align -c 'SELECT 1' >/dev/null 2>&1; then
      echo "the previous database password remained valid after rotation" >&2
      exit 1
    fi
    test "$(PGPASSWORD=rotated-password ${vmCfg.services.postgresql.package}/bin/psql --no-psqlrc -h 127.0.0.1 -p "$PGPORT" -U mautrix-whatsapp -d mautrix-whatsapp --tuples-only --no-align -c 'SELECT 1')" = 1
    touch "$out"
  '';
  registrationLifecycleCheck = pkgs.runCommand "matrix-whatsapp-bridge-registration-test" { } ''
    set -euo pipefail
    rm -rf ${registrationTestDataDir} ${registrationTestRuntimeDir}
    mkdir -p ${registrationTestDataDir} ${registrationTestRuntimeDir}
    export MAUTRIX_WHATSAPP_APPSERVICE_AS_TOKEN=test-as-token
    export MAUTRIX_WHATSAPP_APPSERVICE_HS_TOKEN=test-hs-token
    export MAUTRIX_WHATSAPP_PROVISIONING_SHARED_SECRET=test-provisioning-secret
    export MAUTRIX_WHATSAPP_ENCRYPTION_PICKLE_KEY=test-pickle-key
    export MAUTRIX_WHATSAPP_PUBLIC_MEDIA_SIGNING_KEY=test-media-signing-key
    export MAUTRIX_WHATSAPP_DIRECT_MEDIA_SERVER_KEY=test-media-server-key
    export PGPASSWORD=test-password

    ${pkgs.bash}/bin/bash ${registrationInactiveScript}
    test -L ${registrationTestRuntimeDir}/current
    test -s ${registrationTestRuntimeDir}/current/whatsapp-registration.yaml
    test -s ${registrationTestRuntimeDir}/current/config.yaml
    test "$(${pkgs.coreutils}/bin/stat -c %a ${registrationTestRuntimeDir}/current/whatsapp-registration.yaml)" = 640
    test "$(${pkgs.coreutils}/bin/stat -c %a ${registrationTestRuntimeDir}/current/config.yaml)" = 600
    test ! -e ${registrationTestDataDir}/config.yaml
    ${pkgs.gnugrep}/bin/grep -qF 'test-provisioning-secret' ${registrationTestRuntimeDir}/current/config.yaml
    ${pkgs.gnugrep}/bin/grep -qF 'test-pickle-key' ${registrationTestRuntimeDir}/current/config.yaml
    ${pkgs.gnugrep}/bin/grep -qF 'test-media-signing-key' ${registrationTestRuntimeDir}/current/config.yaml
    ${pkgs.gnugrep}/bin/grep -qF 'test-media-server-key' ${registrationTestRuntimeDir}/current/config.yaml
    test "$(${pkgs.yq}/bin/yq -r '.appservice.as_token' ${registrationTestRuntimeDir}/current/config.yaml)" = generated-as-token
    test "$(${pkgs.yq}/bin/yq -r '.appservice.hs_token' ${registrationTestRuntimeDir}/current/config.yaml)" = generated-hs-token

    rm -f ${registrationTestRuntimeDir}/current
    mkdir -p ${registrationTestRuntimeDir}/.generation-existing
    printf 'existing-config\n' > ${registrationTestRuntimeDir}/.generation-existing/config.yaml
    printf 'existing-registration\n' > ${registrationTestRuntimeDir}/.generation-existing/whatsapp-registration.yaml
    ln -s .generation-existing ${registrationTestRuntimeDir}/current

    if ${pkgs.bash}/bin/bash ${registrationSynapseActiveScript}; then
      echo "registration replacement was not blocked while Synapse was active" >&2
      exit 1
    fi
    if ${pkgs.bash}/bin/bash ${registrationBridgeActiveScript}; then
      echo "registration replacement was not blocked while the bridge was active" >&2
      exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -q '^existing-config$' ${registrationTestRuntimeDir}/current/config.yaml
    ${pkgs.gnugrep}/bin/grep -q '^existing-registration$' ${registrationTestRuntimeDir}/current/whatsapp-registration.yaml

    if ${pkgs.bash}/bin/bash ${registrationFailureScript}; then
      echo "registration generator failure was not propagated" >&2
      exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -q '^existing-config$' ${registrationTestRuntimeDir}/current/config.yaml
    ${pkgs.gnugrep}/bin/grep -q '^existing-registration$' ${registrationTestRuntimeDir}/current/whatsapp-registration.yaml

    if ${pkgs.bash}/bin/bash ${registrationMissingOutputScript}; then
      echo "registration replacement succeeded without a generated registration" >&2
      exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -q '^existing-config$' ${registrationTestRuntimeDir}/current/config.yaml
    ${pkgs.gnugrep}/bin/grep -q '^existing-registration$' ${registrationTestRuntimeDir}/current/whatsapp-registration.yaml

    if ${pkgs.bash}/bin/bash ${registrationYqFailureScript}; then
      echo "registration replacement succeeded after yq failed" >&2
      exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -q '^existing-config$' ${registrationTestRuntimeDir}/current/config.yaml
    ${pkgs.gnugrep}/bin/grep -q '^existing-registration$' ${registrationTestRuntimeDir}/current/whatsapp-registration.yaml

    unset MAUTRIX_WHATSAPP_PROVISIONING_SHARED_SECRET
    if ${pkgs.bash}/bin/bash ${registrationInactiveScript}; then
      echo "missing bridge secret was not rejected" >&2
      exit 1
    fi
    ${pkgs.gnugrep}/bin/grep -q '^existing-config$' ${registrationTestRuntimeDir}/current/config.yaml
    ${pkgs.gnugrep}/bin/grep -q '^existing-registration$' ${registrationTestRuntimeDir}/current/whatsapp-registration.yaml
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
assert lib.hasInfix "-i microvm0" matrixFirewallAllow;
assert matrixBackupJob.repo == "ssh://zh6100@zh6100.rsync.net/./matrix-borg";
assert matrixBackupJob.repo != immichBackupJob.repo;
assert matrixBackupJob.startAt == "04:30";
assert matrixBackupJob.encryption.mode == "repokey-blake2";
assert matrixBackupJob.encryption.passCommand == "cat ${matrixBackupPassphrase.path}";
assert matrixBackupJob.encryption.passCommand != immichBackupJob.encryption.passCommand;
assert lib.hasInfix "-i /root/.ssh/matrix-rsyncnet" matrixBackupJob.environment.BORG_RSH;
assert !(lib.hasInfix "/root/.ssh/immich-rsyncnet" matrixBackupJob.environment.BORG_RSH);
assert
  matrixBackupJob.paths == [
    "${hostCfg.sys.virtualisation.microvm.stateDir}/.zfs/snapshot/matrix-synapse-rsyncnet/matrix-synapse-vm"
  ];
assert matrixBackupPassphrase.owner == "root";
assert matrixBackupPassphrase.group == "root";
assert matrixBackupPassphrase.mode == "0400";
assert matrixBackupPassphrase.path != hostCfg.sys.secrets.borgKeyFile;
assert matrixStorage.optionalBackupVolumes == [ matrixStorage.bridgeVolume ];
assert lib.hasInfix matrixStorage.bridgeVolume.image matrixBackupJob.preHook;
assert lib.elem "network-online.target" matrixBackupService.wants;
assert lib.elem "sops-install-secrets.service" matrixBackupService.wants;
assert lib.elem "sops-install-secrets.service" matrixBackupService.requires;
assert lib.elem "sops-install-secrets.service" matrixBackupService.after;
assert lib.elem "multi-user.target" matrixBackupService.after;
assert lib.elem "microvm@matrix-synapse-vm.service" matrixBackupService.after;
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
assert !(bridgeSettings.bridge.permissions ? "*");
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
assert lib.elem "/run/matrix-whatsapp-registration/current/whatsapp-registration.yaml"
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
assert lib.all (
  name: vmCfg.sops.secrets.${name}.restartUnits == [ "mautrix-whatsapp-stack-reconcile.service" ]
) bridgeSecrets;
assert bridgeDatabaseSecret.owner == "root";
assert bridgeDatabaseSecret.group == "postgres";
assert bridgeDatabaseSecret.mode == "0440";
assert lib.hasInfix "host    mautrix-whatsapp    mautrix-whatsapp    127.0.0.1/32    scram-sha-256"
  vmCfg.services.postgresql.authentication;
assert bridgeDatabaseSecret.restartUnits == [ "mautrix-whatsapp-stack-reconcile.service" ];
assert matrixInstance.portForward.enable == false;
assert matrixInstance.portForward.ports == [ ];
assert !(lib.elem 11060 vmCfg.networking.firewall.allowedTCPPorts);
assert !(lib.elem 29318 vmCfg.networking.firewall.allowedTCPPorts);
assert vmCfg.systemd.network.links."10-microvm-primary".linkConfig.Name == "microvm0";
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
assert registrationService.partOf == [ "mautrix-whatsapp-stack.target" ];
assert registrationService.restartTriggers == [ ];
assert synapseService.restartTriggers == [ ];
assert synapseService.wantedBy == [ ];
assert lib.elem "mautrix-whatsapp-registration.service" synapseService.requires;
assert lib.elem "mautrix-whatsapp-registration.service" synapseService.after;
assert synapseService.partOf == [ "mautrix-whatsapp-stack.target" ];
assert lib.hasInfix "--generate-registration" registrationService.script;
assert lib.hasInfix "mv -T -- \"$generationLink\" \"$currentLink\"" registrationService.script;
assert lib.hasInfix "ln -s -- \"$(basename \"$generationDirectory\")\" \"$generationLink\""
  registrationService.script;
assert lib.hasInfix "/run/matrix-whatsapp-registration/current/whatsapp-registration.yaml"
  bridgeService.preStart;
assert dbInitService.serviceConfig.Type == "oneshot";
assert dbInitService.serviceConfig.User == vmCfg.services.postgresql.superUser;
assert lib.elem bridgeDatabaseSecret.path dbInitService.serviceConfig.ReadOnlyPaths;
assert lib.elem "sops-install-secrets.service" dbInitService.after;
assert lib.elem "sops-install-secrets.service" dbInitService.requires;
assert lib.hasInfix "ALTER ROLE" dbInitService.script;
assert lib.hasInfix "SET password_encryption = 'scram-sha-256'" dbInitService.script;
assert lib.hasInfix "\\getenv bridge_password BRIDGE_DATABASE_PASSWORD" dbInitService.script;
assert !(lib.hasInfix "${pkgs.gnugrep}/bin/grep" dbInitService.script);
assert lib.hasInfix "/run/matrix-whatsapp-registration/current/config.yaml"
  bridgeService.serviceConfig.ExecStart;
assert lib.hasInfix "/run/matrix-whatsapp-registration/current/whatsapp-registration.yaml"
  bridgeService.serviceConfig.ExecStart;
assert lib.elem "mautrix-whatsapp-db-init.service" bridgeService.requires;
assert lib.elem "mautrix-whatsapp-registration.service" bridgeService.requires;
assert lib.elem "mautrix-whatsapp-registration.service" bridgeService.after;
assert lib.elem "matrix-synapse.service" bridgeService.requires;
assert lib.elem "matrix-synapse.service" bridgeService.after;
assert bridgeService.partOf == [ "mautrix-whatsapp-stack.target" ];
assert bridgeService.wantedBy == [ ];
assert bridgeService.serviceConfig.User == "mautrix-whatsapp";
assert bridgeService.serviceConfig.PrivateUsers == true;
assert !(lib.elem "AF_UNIX" bridgeService.serviceConfig.RestrictAddressFamilies);
assert lib.elem "AF_INET" bridgeService.serviceConfig.RestrictAddressFamilies;
assert lib.elem "AF_INET6" bridgeService.serviceConfig.RestrictAddressFamilies;
assert lib.elem "10.0.0.0/8" bridgeService.serviceConfig.IPAddressDeny;
assert lib.elem "192.168.0.0/16" bridgeService.serviceConfig.IPAddressDeny;
assert lib.elem "fc00::/7" bridgeService.serviceConfig.IPAddressDeny;
assert bridgeService.serviceConfig.StateDirectoryMode == "0700";
assert bridgeService.serviceConfig.MemoryHigh == "512M";
assert bridgeService.serviceConfig.MemoryMax == "1G";
assert bridgeService.serviceConfig.TasksMax == 256;
assert lib.elem pkgs.ffmpeg-headless bridgeService.path;
assert lib.elem pkgs.lottieconverter bridgeService.path;
assert lib.all (unit: lib.elem unit stackTarget.requires) [
  "sops-install-secrets.service"
  "postgresql.service"
  "mautrix-whatsapp-db-init.service"
  "mautrix-whatsapp-registration.service"
  "matrix-synapse.service"
  "mautrix-whatsapp.service"
];
assert stackTarget.partOf == [ "postgresql.service" ];
assert stackTarget.bindsTo == [ "postgresql.service" ];
assert lib.elem "mautrix-whatsapp-stack.target" postgresqlService.wants;
assert reconcileService.serviceConfig.Type == "oneshot";
assert reconcileService.serviceConfig.RemainAfterExit;
assert lib.elem "mautrix-whatsapp-stack.target" reconcileService.after;
assert
  reconcileService.serviceConfig.ExecStart
  == "${pkgs.systemd}/bin/systemctl restart mautrix-whatsapp-stack.target";
assert reconcileService.restartTriggers != [ ];
pkgs.runCommand "matrix-whatsapp-bridge-tests" { } ''
  test -e ${scriptSyntaxCheck}
  test -e ${registrationLifecycleCheck}
  test -e ${dbInitScenariosCheck}
  touch "$out"
''
